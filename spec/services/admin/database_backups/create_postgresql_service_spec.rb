require "rails_helper"
require "fileutils"
require "json"
require "zip"

RSpec.describe Admin::DatabaseBackups::CreatePostgresqlService do
  let(:admin) { create(:user, :admin, email_address: "admin@example.test") }
  let(:tmp_dir) { Rails.root.join("tmp", "postgresql-backup-service-spec-#{SecureRandom.hex(4)}") }

  around do |example|
    previous_root = Admin::DatabaseBackups.backup_root
    Admin::DatabaseBackups.backup_root = tmp_dir
    example.run
  ensure
    Admin::DatabaseBackups.backup_root = previous_root
    FileUtils.rm_rf(tmp_dir)
  end

  it "creates PostgreSQL DDL, data SQL, manifest, and zip files" do
    user = create(:user, email_address: "player@example.test", nickname: "player")

    result = described_class.call(user: admin)

    expect(result).to be_success
    backup_dir = tmp_dir.join(result.backup.fetch(:id))
    schema_path = backup_dir.join(result.backup.fetch(:files).find { |file| file.fetch(:type) == "postgresql_ddl" }.fetch(:name))
    data_path = backup_dir.join(result.backup.fetch(:files).find { |file| file.fetch(:type) == "postgresql_data" }.fetch(:name))
    zip_path = backup_dir.join(result.backup.fetch(:files).find { |file| file.fetch(:type) == "zip" }.fetch(:name))
    schema_sql = schema_path.read
    data_sql = data_path.read

    expect(schema_sql).to include('CREATE TABLE "users"')
    expect(schema_sql).to include('CREATE UNIQUE INDEX "index_users_on_email_address"')
    expect(schema_sql).to include('"hot_zone" boolean DEFAULT FALSE NOT NULL')
    expect(schema_sql).to include('ON DELETE SET NULL')
    expect(data_sql).to include('INSERT INTO "users"')
    expect(data_sql).to include(user.email_address)
    expect(data_sql).to include("SELECT setval(pg_get_serial_sequence('users', 'id')")
    expect(zip_path).to exist

    manifest = JSON.parse(backup_dir.join("manifest.json").read)
    expect(manifest.fetch("target_adapter")).to eq("PostgreSQL")
    expect(manifest.fetch("files").map { |file| file.fetch("type") }).to include("postgresql_ddl", "postgresql_data", "zip")

    Zip::File.open(zip_path) do |zip|
      expect(zip.find_entry(schema_path.basename.to_s)).to be_present
      expect(zip.find_entry(data_path.basename.to_s)).to be_present
      expect(zip.find_entry("manifest.json")).to be_present
    end
  end
end
