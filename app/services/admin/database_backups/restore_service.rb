require "digest"
require "fileutils"
require "json"
require "open3"
require "securerandom"
require "zip"

module Admin
  module DatabaseBackups
    class RestoreService
      Result = Data.define(:success, :backup, :error) do
        def success? = success
      end

      MAX_UPLOAD_BYTES = 500.megabytes
      ALLOWED_EXTENSIONS = %w[.zip .sqlite3 .sqlite .db].freeze

      def self.call(upload:, user:)
        new(upload:, user:).call
      end

      def initialize(upload:, user:)
        @upload = upload
        @user = user
      end

      def call
        return failure("운영 환경에서는 DB 복원을 실행할 수 없습니다.") if Rails.env.production?
        return failure("백업 파일을 선택해 주세요.") if @upload.blank?
        return failure("허용되지 않는 백업 파일 형식입니다.") unless allowed_extension?
        return failure("백업 파일이 너무 큽니다. 최대 #{MAX_UPLOAD_BYTES / 1.megabyte}MB까지 업로드할 수 있습니다.") if upload_size > MAX_UPLOAD_BYTES

        with_stage_dir do
          uploaded_path = copy_upload_to_stage
          sqlite_path = sqlite_path_from(uploaded_path)
          validate_sqlite!(sqlite_path)

          pre_restore_backup = create_pre_restore_backup
          restore_database(sqlite_path)

          Rails.logger.warn(
            "[DataManagement::Restore] user_id=#{@user.id} email=#{@user.email_address} " \
            "filename=#{original_filename} sha256=#{sha256(sqlite_path)} pre_restore_backup_id=#{pre_restore_backup&.dig(:id)}"
          )

          Result.new(true, pre_restore_backup, nil)
        end
      rescue => e
        reconnect_database(raise_errors: false)
        Rails.logger.error("[DataManagement::Restore] failed user_id=#{@user&.id} error=#{e.class}: #{e.message}")
        failure(e.message)
      end

      private

      def with_stage_dir
        @stage_dir = Rails.root.join("tmp", "db_restore_uploads", "#{Time.current.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}")
        FileUtils.mkdir_p(@stage_dir)
        yield
      ensure
        FileUtils.rm_rf(@stage_dir) if @stage_dir
      end

      def copy_upload_to_stage
        path = @stage_dir.join(safe_filename)
        FileUtils.cp(upload_tempfile_path, path)
        path
      end

      def sqlite_path_from(uploaded_path)
        return sqlite_path_from_zip(uploaded_path) if uploaded_path.extname.downcase == ".zip"

        uploaded_path
      end

      def sqlite_path_from_zip(uploaded_path)
        extract_dir = @stage_dir.join("extracted")
        FileUtils.mkdir_p(extract_dir)

        Zip::File.open(uploaded_path) do |zip|
          zip.each do |entry|
            next if entry.directory?
            raise "백업 zip에 허용되지 않는 경로가 포함되어 있습니다." unless safe_zip_entry?(entry.name)

            target_path = extract_dir.join(entry.name)
            File.open(target_path, "wb") do |file|
              IO.copy_stream(entry.get_input_stream, file)
            end
          end
        end

        manifest_path = extract_dir.join("manifest.json")
        raise "백업 manifest.json을 찾을 수 없습니다." unless manifest_path.file?

        manifest = JSON.parse(manifest_path.read)
        sqlite_entry = manifest.fetch("files").find { |file| file["type"] == "sqlite3" } ||
                       manifest.fetch("files").find { |file| File.extname(file.fetch("name", "")).in?(%w[.sqlite3 .sqlite .db]) }
        raise "백업 zip에서 SQLite 파일을 찾을 수 없습니다." unless sqlite_entry

        sqlite_path = extract_dir.join(File.basename(sqlite_entry.fetch("name")))
        raise "백업 zip의 SQLite 파일을 찾을 수 없습니다." unless sqlite_path.file?
        raise "백업 파일 checksum이 일치하지 않습니다." unless sqlite_entry["sha256"].blank? || sha256(sqlite_path) == sqlite_entry["sha256"]

        sqlite_path
      rescue JSON::ParserError, KeyError
        raise "백업 manifest 형식이 올바르지 않습니다."
      end

      def validate_sqlite!(sqlite_path)
        raise "SQLite 백업 파일을 찾을 수 없습니다." unless sqlite_path.file?
        raise "SQLite 백업 파일이 비어 있습니다." if sqlite_path.size.zero?

        stdout, stderr, status = Open3.capture3("sqlite3", sqlite_path.to_s, "PRAGMA integrity_check;")
        raise "SQLite 무결성 검사에 실패했습니다: #{stderr.presence || stdout.presence || status.exitstatus}" unless status.success?
        raise "SQLite 무결성 검사에 실패했습니다: #{stdout.strip}" unless stdout.strip == "ok"
      end

      def create_pre_restore_backup
        result = Admin::DatabaseBackups::CreateService.call(user: @user, include_sql_dump: false)
        raise "복원 전 현재 DB 백업 생성에 실패했습니다: #{result.error}" unless result.success?

        result.backup
      end

      def restore_database(sqlite_path)
        target_path = database_path
        temp_target_path = target_path.dirname.join(".#{target_path.basename}.restore-#{SecureRandom.hex(4)}")

        FileUtils.mkdir_p(target_path.dirname)
        FileUtils.cp(sqlite_path, temp_target_path)

        ActiveRecord::Base.connection_pool.disconnect!
        FileUtils.mv(temp_target_path, target_path)
        reconnect_database
        migrate_database
      ensure
        FileUtils.rm_f(temp_target_path) if temp_target_path
      end

      def reconnect_database(raise_errors: true)
        ActiveRecord::Base.establish_connection
        ActiveRecord::Base.connection.execute("SELECT 1")
      rescue => e
        raise e if raise_errors

        nil
      end

      def migrate_database
        previous_verbose = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Tasks::DatabaseTasks.migrate
      ensure
        ActiveRecord::Migration.verbose = previous_verbose
      end

      def database_path
        configured = Pathname.new(ActiveRecord::Base.connection_db_config.database)
        configured.absolute? ? configured : Rails.root.join(configured)
      end

      def allowed_extension?
        File.extname(original_filename).downcase.in?(ALLOWED_EXTENSIONS)
      end

      def safe_zip_entry?(name)
        name == File.basename(name) && name.exclude?("\0")
      end

      def safe_filename
        basename = File.basename(original_filename).presence || "database-backup.sqlite3"
        basename.gsub(/[^a-zA-Z0-9._-]/, "_")
      end

      def original_filename
        @upload.respond_to?(:original_filename) ? @upload.original_filename.to_s : @upload.to_s
      end

      def upload_tempfile_path
        return @upload.tempfile.path if @upload.respond_to?(:tempfile)

        @upload.path
      end

      def upload_size
        return @upload.size if @upload.respond_to?(:size)

        File.size(upload_tempfile_path)
      end

      def sha256(path)
        Digest::SHA256.file(path).hexdigest
      end

      def failure(message)
        Result.new(false, nil, message)
      end
    end
  end
end
