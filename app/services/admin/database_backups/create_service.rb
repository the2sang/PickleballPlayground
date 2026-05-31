require "digest"
require "fileutils"
require "json"
require "open3"
require "securerandom"
require "zip"

module Admin
  module DatabaseBackups
    class CreateService
      Result = Data.define(:success, :backup, :error) do
        def success? = success
      end

      def self.call(user:, include_sql_dump: false)
        new(user:, include_sql_dump:).call
      end

      def initialize(user:, include_sql_dump: false)
        @user = user
        @include_sql_dump = include_sql_dump
      end

      def call
        FileUtils.mkdir_p(Admin::DatabaseBackups.backup_root)
        FileUtils.mkdir_p(backup_dir)

        create_sqlite_backup
        create_sql_dump if @include_sql_dump
        create_manifest
        create_zip
        rewrite_manifest_with_zip

        Rails.logger.info(
          "[DataManagement::Backup] user_id=#{@user.id} email=#{@user.email_address} backup_id=#{backup_id} " \
          "sqlite_sha256=#{sha256(sqlite_backup_path)} include_sql_dump=#{@include_sql_dump}"
        )

        Result.new(true, manifest, nil)
      rescue => e
        FileUtils.rm_rf(backup_dir) if backup_dir&.directory?
        Rails.logger.error("[DataManagement::Backup] failed user_id=#{@user&.id} error=#{e.class}: #{e.message}")
        Result.new(false, nil, e.message)
      end

      private

      def create_sqlite_backup
        source = SQLite3::Database.new(database_path.to_s, readonly: true)
        dest   = SQLite3::Database.new(sqlite_backup_path.to_s)
        backup = SQLite3::Backup.new(dest, "main", source, "main")
        result = backup.step(-1)
        backup.finish
        raise "sqlite3 backup did not complete (status: #{result})" unless result == SQLite3::Constants::ErrorCode::DONE
      ensure
        dest&.close
        source&.close
      end

      def create_sql_dump
        File.open(sql_dump_path, "wb") do |file|
          Open3.popen3("sqlite3", sqlite_backup_path.to_s, ".dump") do |stdin, stdout, stderr, wait_thread|
            stdin.close
            IO.copy_stream(stdout, file)

            error = stderr.read
            status = wait_thread.value
            raise "sqlite3 dump failed: #{error.presence || status.exitstatus}" unless status.success?
          end
        end
      end

      def create_manifest
        manifest_path.write(JSON.pretty_generate(manifest_without_zip))
      end

      def rewrite_manifest_with_zip
        manifest_path.write(JSON.pretty_generate(manifest))
      end

      def create_zip
        Zip::File.open(zip_path, create: true) do |zip|
          (backup_files + [ manifest_path ]).each do |file|
            zip.add(file.basename.to_s, file.to_s)
          end
        end
      end

      def manifest
        manifest_without_zip.merge(
          files: manifest_without_zip.fetch(:files) + [ file_entry(zip_path, "zip") ]
        )
      end

      def manifest_without_zip
        {
          id: backup_id,
          created_at: Time.current.iso8601,
          created_by: {
            id: @user.id,
            email_address: @user.email_address
          },
          rails_env: Rails.env,
          database_path: database_path.to_s,
          include_sql_dump: @include_sql_dump,
          files: backup_files.map { |file| file_entry(file, file_type(file)) }
        }
      end

      def backup_files
        files = [ sqlite_backup_path ]
        files << sql_dump_path if @include_sql_dump
        files
      end

      def file_entry(path, type)
        {
          name: path.basename.to_s,
          type: type,
          size_bytes: path.size,
          sha256: sha256(path)
        }
      end

      def file_type(path)
        case path.extname
        when ".sqlite3" then "sqlite3"
        when ".sql" then "sql_dump"
        when ".json" then "manifest"
        else "file"
        end
      end

      def database_path
        configured = Pathname.new(ActiveRecord::Base.connection_db_config.database)
        configured.absolute? ? configured : Rails.root.join(configured)
      end

      def backup_id
        @backup_id ||= "codedash-db-backup-#{Rails.env}-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(3)}"
      end

      def backup_dir
        @backup_dir ||= Admin::DatabaseBackups.backup_root.join(backup_id)
      end

      def sqlite_backup_path
        backup_dir.join("#{backup_id}.sqlite3")
      end

      def sql_dump_path
        backup_dir.join("#{backup_id}.sql")
      end

      def manifest_path
        backup_dir.join("manifest.json")
      end

      def zip_path
        backup_dir.join("#{backup_id}.zip")
      end

      def sha256(path)
        Digest::SHA256.file(path).hexdigest
      end
    end
  end
end
