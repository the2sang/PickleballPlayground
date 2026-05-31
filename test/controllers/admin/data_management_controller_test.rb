require "test_helper"
require "fileutils"
require "json"

module Admin
  class DataManagementControllerTest < ActionDispatch::IntegrationTest
    BACKUP_ROOT = Rails.root.join("storage", "db_backups")

    setup do
      FileUtils.rm_rf(BACKUP_ROOT)
    end

    teardown do
      FileUtils.rm_rf(BACKUP_ROOT)
    end

    test "admin sees database backup panel" do
      sign_in_as(users(:admin))

      get admin_data_management_path

      assert_response :success
      assert_select "#db-backups"
      assert_select "button", "백업 생성"
    end

    test "admin creates sqlite backup with optional sql dump and zip" do
      sign_in_as(users(:admin))

      post admin_data_management_backups_path, params: { include_sql_dump: "1" }

      assert_redirected_to admin_data_management_path(anchor: "db-backups")
      assert flash[:notice], "Backup failed: #{flash[:alert]}"

      assert BACKUP_ROOT.exist?, "BACKUP_ROOT was not created"
      backup_dir = BACKUP_ROOT.children.find(&:directory?)
      assert backup_dir
      assert backup_dir.join("manifest.json").file?

      manifest = JSON.parse(backup_dir.join("manifest.json").read)
      file_names = manifest.fetch("files").map { |file| file.fetch("name") }

      assert file_names.any? { |name| name.end_with?(".sqlite3") }
      assert file_names.any? { |name| name.end_with?(".sql") }
      assert file_names.any? { |name| name.end_with?(".zip") }
    end

    test "admin downloads zip backup" do
      sign_in_as(users(:admin))
      result = Admin::DatabaseBackups::CreateService.call(user: users(:admin), include_sql_dump: false)
      assert result.success?, "CreateService failed: #{result.error}"
      zip_file = result.backup.fetch(:files).find { |file| file.fetch(:type) == "zip" }

      get admin_data_management_backup_path(id: result.backup.fetch(:id), file: zip_file.fetch(:name))

      assert_response :success
      assert_equal "application/zip", response.media_type
      assert_match "attachment", response.headers["Content-Disposition"]
      assert_match zip_file.fetch(:name), response.headers["Content-Disposition"]
    end

    test "regular user cannot create database backup" do
      sign_in_as(users(:one))

      post admin_data_management_backups_path

      assert_redirected_to root_path
      assert_not BACKUP_ROOT.directory?
    end
  end
end
