require "rails_helper"

RSpec.describe "Admin::DataManagement", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    allow(Admin::DatabaseBackups::ListService).to receive(:call).and_return([])
  end

  describe "GET /admin/data_management" do
    it "shows the production backup restore panel" do
      sign_in(admin)

      get admin_data_management_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("운영 백업 업로드 복원")
    end
  end

  describe "POST /admin/data_management/backups/restore" do
    it "requires restore confirmation" do
      sign_in(admin)

      post admin_data_management_backup_restore_path,
           params: { backup_file: upload_file }

      expect(response).to redirect_to(admin_data_management_path(anchor: "db-restore"))
      expect(flash[:alert]).to eq("복원 확인 체크박스를 선택해 주세요.")
    end

    it "restores uploaded backup through restore service" do
      sign_in(admin)
      result = Admin::DatabaseBackups::RestoreService::Result.new(true, { id: "pre-restore" }, nil)

      expect(Admin::DatabaseBackups::RestoreService).to receive(:call)
        .with(upload: kind_of(ActionDispatch::Http::UploadedFile), user: admin)
        .and_return(result)

      post admin_data_management_backup_restore_path,
           params: { backup_file: upload_file, confirm_restore: "1" }

      expect(response).to redirect_to(admin_data_management_path(anchor: "db-restore"))
      expect(flash[:notice]).to include("DB 복원이 완료되었습니다")
    end
  end

  def upload_file
    Rack::Test::UploadedFile.new(
      Rails.root.join("db", "schema.rb"),
      "application/vnd.sqlite3",
      original_filename: "backup.sqlite3"
    )
  end
end
