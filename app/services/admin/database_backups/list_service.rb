require "json"

module Admin
  module DatabaseBackups
    class ListService
      def self.call = new.call

      def call
        return [] unless Admin::DatabaseBackups.backup_root.directory?

        Admin::DatabaseBackups.backup_root.children.select(&:directory?).filter_map do |dir|
          manifest_path = dir.join("manifest.json")
          next unless manifest_path.file?

          manifest = JSON.parse(manifest_path.read)
          manifest.merge(
            "id" => dir.basename.to_s,
            "zip_filename" => zip_filename_for(manifest),
            "created_at" => Time.zone.parse(manifest.fetch("created_at"))
          )
        rescue JSON::ParserError, KeyError, ArgumentError
          nil
        end.sort_by { |backup| backup["created_at"] }.reverse
      end

      private

      def zip_filename_for(manifest)
        manifest.fetch("files").find { |file| file["type"] == "zip" }&.fetch("name", nil)
      end
    end
  end
end
