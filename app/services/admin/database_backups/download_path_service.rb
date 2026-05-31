require "json"

module Admin
  module DatabaseBackups
    class DownloadPathService
      Result = Data.define(:success, :path, :filename, :content_type, :error) do
        def success? = success
      end

      SAFE_ID = /\A[a-zA-Z0-9._-]+\z/

      def self.call(backup_id:, filename:)
        new(backup_id:, filename:).call
      end

      def initialize(backup_id:, filename:)
        @backup_id = backup_id.to_s
        @filename = File.basename(filename.to_s)
      end

      def call
        return failure("잘못된 백업 요청입니다.") unless safe_segment?(@backup_id) && safe_segment?(@filename)

        backup_dir = Admin::DatabaseBackups.backup_root.join(@backup_id).expand_path
        path = backup_dir.join(@filename).expand_path
        return failure("백업 파일을 찾을 수 없습니다.") unless path.file?
        return failure("백업 파일을 찾을 수 없습니다.") unless path.to_s.start_with?("#{backup_dir}/")
        return failure("다운로드할 수 없는 파일입니다.") unless downloadable?(backup_dir, path)

        Result.new(true, path, @filename, content_type_for(@filename), nil)
      end

      private

      def safe_segment?(value)
        value.match?(SAFE_ID)
      end

      def downloadable?(backup_dir, path)
        manifest = JSON.parse(backup_dir.join("manifest.json").read)
        allowed = manifest.fetch("files").map { |file| file.fetch("name") }
        allowed.include?(path.basename.to_s)
      rescue JSON::ParserError, Errno::ENOENT, KeyError
        false
      end

      def content_type_for(filename)
        case File.extname(filename)
        when ".zip" then "application/zip"
        when ".sql" then "application/sql"
        when ".sqlite3" then "application/vnd.sqlite3"
        when ".json" then "application/json"
        else "application/octet-stream"
        end
      end

      def failure(message)
        Result.new(false, nil, nil, nil, message)
      end
    end
  end
end
