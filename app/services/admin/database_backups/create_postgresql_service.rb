require "bigdecimal"
require "digest"
require "fileutils"
require "json"
require "securerandom"
require "set"
require "zip"

module Admin
  module DatabaseBackups
    class CreatePostgresqlService
      Result = Data.define(:success, :backup, :error) do
        def success? = success
      end

      def self.call(user:)
        new(user:).call
      end

      def initialize(user:)
        @user = user
        @connection = ActiveRecord::Base.connection
      end

      def call
        FileUtils.mkdir_p(Admin::DatabaseBackups.backup_root)
        FileUtils.mkdir_p(backup_dir)

        create_schema_dump
        create_data_dump
        create_manifest
        create_zip
        rewrite_manifest_with_zip

        Rails.logger.info(
          "[DataManagement::PostgresqlBackup] user_id=#{@user.id} email=#{@user.email_address} " \
          "backup_id=#{backup_id} schema_sha256=#{sha256(schema_dump_path)} data_sha256=#{sha256(data_dump_path)}"
        )

        Result.new(true, manifest, nil)
      rescue => e
        FileUtils.rm_rf(backup_dir) if backup_dir&.directory?
        Rails.logger.error("[DataManagement::PostgresqlBackup] failed user_id=#{@user&.id} error=#{e.class}: #{e.message}")
        Result.new(false, nil, e.message)
      end

      private

      def create_schema_dump
        File.open(schema_dump_path, "wb") do |file|
          file.puts "-- PostgreSQL DDL backup generated from SQLite"
          file.puts "-- Generated at: #{Time.current.iso8601}"
          file.puts
          file.puts "BEGIN;"
          file.puts

          ordered_tables.each do |table|
            file.puts create_table_sql(table)
            file.puts
          end

          tables.each do |table|
            index_sql(table).each { |sql| file.puts "#{sql};" }
          end
          file.puts

          tables.each do |table|
            foreign_key_sql(table).each { |sql| file.puts "#{sql};" }
          end

          file.puts
          file.puts "COMMIT;"
        end
      end

      def create_data_dump
        File.open(data_dump_path, "wb") do |file|
          file.puts "-- PostgreSQL data backup generated from SQLite"
          file.puts "-- Generated at: #{Time.current.iso8601}"
          file.puts
          file.puts "BEGIN;"
          file.puts

          ordered_tables.each do |table|
            dump_table_data(file, table)
          end

          file.puts
          ordered_tables.each do |table|
            sequence_reset_sql(table).then { |sql| file.puts sql if sql }
          end

          file.puts "COMMIT;"
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

      def create_table_sql(table)
        column_lines = @connection.columns(table).map { |column| "  #{column_sql(table, column)}" }

        [
          "CREATE TABLE #{quote_identifier(table)} (",
          column_lines.join(",\n"),
          ");"
        ].join("\n")
      end

      def column_sql(table, column)
        fragments = [ quote_identifier(column.name) ]
        primary_key = @connection.primary_key(table)

        if column.name == primary_key
          fragments << primary_key_type_for(table, column)
          fragments << "PRIMARY KEY"
          return fragments.join(" ")
        end

        fragments << postgresql_type_for(table, column)
        fragments << "DEFAULT #{default_sql_for(table, column)}" if !column.default.nil? || column.default_function.present?
        fragments << "NOT NULL" unless column.null
        fragments.join(" ")
      end

      def index_sql(table)
        @connection.indexes(table).map do |index|
          unique = index.unique ? "UNIQUE " : ""
          "CREATE #{unique}INDEX #{quote_identifier(index.name)} ON #{quote_identifier(table)} (#{index_columns_sql(index)})#{where_sql(index)}"
        end
      end

      def foreign_key_sql(table)
        @connection.foreign_keys(table).map do |fk|
          parts = [
            "ALTER TABLE #{quote_identifier(table)}",
            "ADD CONSTRAINT #{quote_identifier(fk.name.presence || foreign_key_name(table, fk))}",
            "FOREIGN KEY (#{Array(fk.column).map { |column| quote_identifier(column) }.join(', ')})",
            "REFERENCES #{quote_identifier(fk.to_table)} (#{Array(fk.primary_key).map { |column| quote_identifier(column) }.join(', ')})"
          ]
          parts << "ON DELETE #{referential_action_sql(fk.on_delete)}" if fk.on_delete
          parts << "ON UPDATE #{referential_action_sql(fk.on_update)}" if fk.on_update
          parts.join(" ")
        end
      end

      def dump_table_data(file, table)
        columns = @connection.columns(table)
        return if columns.empty?

        quoted_columns = columns.map { |column| quote_identifier(column.name) }.join(", ")
        rows = @connection.select_all("SELECT * FROM #{quote_identifier(table)}#{order_sql(table)}")

        file.puts "-- #{table}: #{rows.length} rows"
        rows.each do |row|
          values = columns.map { |column| quote_postgresql_value(row[column.name], table, column) }.join(", ")
          file.puts "INSERT INTO #{quote_identifier(table)} (#{quoted_columns}) VALUES (#{values});"
        end
        file.puts
      end

      def sequence_reset_sql(table)
        primary_key = @connection.primary_key(table)
        return nil unless primary_key == "id"

        column = @connection.columns(table).find { |candidate| candidate.name == primary_key }
        return nil unless column&.type == :integer

        quoted_table = quote_literal(table)
        quoted_column = quote_literal(primary_key)

        "SELECT setval(pg_get_serial_sequence(#{quoted_table}, #{quoted_column}), COALESCE((SELECT MAX(#{quote_identifier(primary_key)}) FROM #{quote_identifier(table)}), 1), EXISTS (SELECT 1 FROM #{quote_identifier(table)}));"
      end

      def order_sql(table)
        primary_key = @connection.primary_key(table)
        return "" if primary_key.blank?

        " ORDER BY #{quote_identifier(primary_key)}"
      end

      def ordered_tables
        @ordered_tables ||= begin
          remaining = tables.to_set
          ordered = []

          until remaining.empty?
            ready = remaining.select do |table|
              dependencies = @connection.foreign_keys(table).map(&:to_table).to_set
              (dependencies & remaining).empty? || dependencies == Set[table]
            end

            ready = [ remaining.first ] if ready.empty?
            ready.sort.each do |table|
              ordered << table
              remaining.delete(table)
            end
          end

          ordered
        end
      end

      def tables
        @tables ||= @connection.tables.reject { |table| table.start_with?("sqlite_") }.sort
      end

      def postgresql_type_for(table, column)
        return "character varying" if rails_internal_string_primary_key?(table, column)

        case column.type
        when :integer
          integer_type_for(column)
        when :string
          column.limit ? "character varying(#{column.limit})" : "character varying"
        when :text
          "text"
        when :datetime
          "timestamp(6) without time zone"
        when :date
          "date"
        when :time
          "time without time zone"
        when :boolean
          "boolean"
        when :decimal
          decimal_type_for(column)
        when :float
          "double precision"
        when :binary
          "bytea"
        when :json, :jsonb
          "jsonb"
        else
          column.sql_type.presence || "text"
        end
      end

      def primary_key_type_for(table, column)
        return "#{postgresql_type_for(table, column)} NOT NULL" unless column.name == "id" && column.type == :integer

        "#{integer_type_for(column)} GENERATED BY DEFAULT AS IDENTITY"
      end

      def integer_type_for(column)
        column.limit.to_i >= 8 || column.sql_type.to_s.downcase.include?("bigint") ? "bigint" : "integer"
      end

      def decimal_type_for(column)
        return "numeric(#{column.precision},#{column.scale})" if column.precision && column.scale
        return "numeric(#{column.precision})" if column.precision

        "numeric"
      end

      def default_sql_for(table, column)
        return column.default_function if column.default_function.present?

        case effective_column_type(table, column)
        when :boolean
          truthy_default?(column.default) ? "TRUE" : "FALSE"
        when :integer, :float, :decimal
          column.default.to_s
        else
          quote_literal(column.default)
        end
      end

      def truthy_default?(value)
        value == true || value.to_s.in?(%w[1 t true TRUE])
      end

      def quote_postgresql_value(value, table, column)
        return "NULL" if value.nil?

        case effective_column_type(table, column)
        when :boolean
          truthy_default?(value) ? "TRUE" : "FALSE"
        when :integer, :float
          value.to_s
        when :decimal
          value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
        when :datetime, :time
          quote_literal(value.respond_to?(:iso8601) ? value.iso8601 : value.to_s)
        when :date
          quote_literal(value.to_s)
        when :binary
          "decode(#{quote_literal(value.to_s.unpack1('H*'))}, 'hex')"
        else
          quote_literal(value.to_s)
        end
      end

      def effective_column_type(table, column)
        rails_internal_string_primary_key?(table, column) ? :string : column.type
      end

      def rails_internal_string_primary_key?(table, column)
        (table == "schema_migrations" && column.name == "version") ||
          (table == "ar_internal_metadata" && column.name == "key")
      end

      def index_columns_sql(index)
        columns = Array(index.columns).map do |column|
          column_sql = column.to_s.include?("(") ? column.to_s : quote_identifier(column)
          order = index.orders[column]&.to_s&.upcase
          [ column_sql, order ].compact.join(" ")
        end
        columns.join(", ")
      end

      def where_sql(index)
        index.where.present? ? " WHERE #{index.where}" : ""
      end

      def foreign_key_name(table, fk)
        "fk_#{table}_#{Array(fk.column).join('_')}"
      end

      def referential_action_sql(action)
        case action.to_sym
        when :nullify
          "SET NULL"
        when :cascade
          "CASCADE"
        when :restrict
          "RESTRICT"
        else
          action.to_s.upcase
        end
      end

      def quote_identifier(value)
        %("#{value.to_s.gsub('"', '""')}")
      end

      def quote_literal(value)
        "'#{value.to_s.gsub("'", "''")}'"
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
          source_adapter: @connection.adapter_name,
          target_adapter: "PostgreSQL",
          files: backup_files.map { |file| file_entry(file, file_type(file)) }
        }
      end

      def backup_files
        [ schema_dump_path, data_dump_path ]
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
        case path.basename.to_s
        when /schema\.sql\z/ then "postgresql_ddl"
        when /data\.sql\z/ then "postgresql_data"
        else "file"
        end
      end

      def database_path
        configured = Pathname.new(ActiveRecord::Base.connection_db_config.database)
        configured.absolute? ? configured : Rails.root.join(configured)
      end

      def backup_id
        @backup_id ||= "codedash-postgresql-backup-#{Rails.env}-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(3)}"
      end

      def backup_dir
        @backup_dir ||= Admin::DatabaseBackups.backup_root.join(backup_id)
      end

      def schema_dump_path
        backup_dir.join("#{backup_id}.schema.sql")
      end

      def data_dump_path
        backup_dir.join("#{backup_id}.data.sql")
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
