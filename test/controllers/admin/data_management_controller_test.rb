require "test_helper"
require "fileutils"
require "json"

module Admin
  class DataManagementControllerTest < ActionDispatch::IntegrationTest
    setup do
      # Each parallel test process gets its own backup root to prevent race conditions.
      @backup_root = Rails.root.join("storage", "db_backups_test_#{Process.pid}")
      Admin::DatabaseBackups.backup_root = @backup_root
      FileUtils.rm_rf(@backup_root)
    end

    teardown do
      FileUtils.rm_rf(@backup_root)
      Admin::DatabaseBackups.backup_root = nil
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

      assert @backup_root.exist?, "BACKUP_ROOT was not created"
      backup_dir = @backup_root.children.find(&:directory?)
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
      assert_not @backup_root.directory?
    end
  end
end
