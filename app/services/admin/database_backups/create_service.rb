require "digest"
require "fileutils"
require "json"
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
        db = SQLite3::Database.new(database_path.to_s)
        db.execute("VACUUM INTO '#{sqlite_backup_path.to_s.gsub("'", "''")}'")
      ensure
        db&.close
      end

      def create_sql_dump
        db = SQLite3::Database.new(sqlite_backup_path.to_s)

        File.open(sql_dump_path, "wb") do |file|
          file.puts "PRAGMA foreign_keys=OFF;"
          file.puts "BEGIN TRANSACTION;"

          dump_tables(db, file)
          dump_schema_objects(db, file)

          file.puts "COMMIT;"
        end
      ensure
        db&.close
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

      def dump_tables(db, file)
        schema_rows(db, "table").each do |row|
          table_name = row.fetch("name")
          file.puts "#{row.fetch("sql")};"
          dump_table_rows(db, file, table_name)
        end
      end

      def dump_schema_objects(db, file)
        %w[index trigger view].each do |type|
          schema_rows(db, type).each { |row| file.puts "#{row.fetch("sql")};" }
        end
      end

      def schema_rows(db, type)
        db.execute(
          <<~SQL,
            SELECT name, sql
            FROM sqlite_schema
            WHERE type = ?
              AND sql IS NOT NULL
              AND name NOT LIKE 'sqlite_%'
            ORDER BY name
          SQL
          type
        ).map { |name, sql| { "name" => name, "sql" => sql } }
      end

      def dump_table_rows(db, file, table_name)
        db.execute("SELECT * FROM #{quote_identifier(table_name)}") do |row|
          values = row.map { |value| quote_sql_value(value) }.join(",")
          file.puts "INSERT INTO #{quote_identifier(table_name)} VALUES(#{values});"
        end
      end

      def quote_identifier(value)
        %("#{value.to_s.gsub('"', '""')}")
      end

      def quote_sql_value(value)
        case value
        when nil
          "NULL"
        when Numeric
          value.to_s
        else
          string = value.to_s
          string.valid_encoding? ? "'#{string.gsub("'", "''")}'" : "X'#{string.unpack1("H*")}'"
        end
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
