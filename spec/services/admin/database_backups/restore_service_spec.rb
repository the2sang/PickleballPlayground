require "rails_helper"
require "digest"
require "fileutils"
require "open3"
require "zip"

RSpec.describe Admin::DatabaseBackups::RestoreService do
  let(:admin) { create(:user, :admin) }
  let(:tmp_dir) { Rails.root.join("tmp", "restore-service-spec-#{SecureRandom.hex(4)}") }

  before do
    FileUtils.mkdir_p(tmp_dir)
    allow_any_instance_of(described_class).to receive(:create_pre_restore_backup).and_return({ id: "pre-restore" })
    allow_any_instance_of(described_class).to receive(:restore_database).and_return(true)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  it "accepts a valid sqlite backup file" do
    sqlite_path = create_sqlite_backup("valid.sqlite3")

    result = described_class.call(upload: uploaded_file(sqlite_path), user: admin)

    expect(result).to be_success
    expect(result.backup).to eq({ id: "pre-restore" })
  end

  it "accepts a generated backup zip with manifest checksum" do
    sqlite_path = create_sqlite_backup("valid.sqlite3")
    zip_path = create_backup_zip(sqlite_path)

    result = described_class.call(upload: uploaded_file(zip_path, content_type: "application/zip"), user: admin)

    expect(result).to be_success
  end

  it "rejects unsupported file extensions" do
    path = tmp_dir.join("backup.txt")
    path.write("not a database")

    result = described_class.call(upload: uploaded_file(path, content_type: "text/plain"), user: admin)

    expect(result).not_to be_success
    expect(result.error).to eq("허용되지 않는 백업 파일 형식입니다.")
  end

  it "rejects unsafe zip entry paths" do
    zip_path = tmp_dir.join("unsafe.zip")
    Zip::File.open(zip_path, create: true) do |zip|
      zip.get_output_stream("../manifest.json") { |file| file.write("{}") }
    end

    result = described_class.call(upload: uploaded_file(zip_path, content_type: "application/zip"), user: admin)

    expect(result).not_to be_success
    expect(result.error).to eq("백업 zip에 허용되지 않는 경로가 포함되어 있습니다.")
  end

  def create_sqlite_backup(filename)
    path = tmp_dir.join(filename)
    _stdout, stderr, status = Open3.capture3("sqlite3", path.to_s, "CREATE TABLE restore_checks (id integer primary key, name text);")
    raise stderr unless status.success?

    path
  end

  def create_backup_zip(sqlite_path)
    manifest = {
      id: "backup-fixture",
      created_at: Time.current.iso8601,
      files: [
        {
          name: sqlite_path.basename.to_s,
          type: "sqlite3",
          size_bytes: sqlite_path.size,
          sha256: Digest::SHA256.file(sqlite_path).hexdigest
        }
      ]
    }
    manifest_path = tmp_dir.join("manifest.json")
    manifest_path.write(JSON.pretty_generate(manifest))

    zip_path = tmp_dir.join("backup.zip")
    Zip::File.open(zip_path, create: true) do |zip|
      zip.add(sqlite_path.basename.to_s, sqlite_path.to_s)
      zip.add("manifest.json", manifest_path.to_s)
    end
    zip_path
  end

  def uploaded_file(path, content_type: "application/vnd.sqlite3")
    Rack::Test::UploadedFile.new(path, content_type, original_filename: path.basename.to_s)
  end
end
