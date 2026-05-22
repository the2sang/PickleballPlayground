require "rails_helper"

RSpec.describe "Tournaments", type: :request do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:other)        { create(:user) }
  let(:club)         { create(:club, owner: owner) }
  let(:tournament)   { create(:tournament, club: club) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end

  let(:valid_params) do
    { tournament: { name: "봄 대회", description: "설명", starts_on: Date.today + 7, ends_on: Date.today + 8 } }
  end

  describe "GET /clubs/:club_id/tournaments" do
    it "비로그인도 접근 가능" do
      get club_tournaments_path(club)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tournaments/:id" do
    it "비로그인도 접근 가능" do
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /clubs/:club_id/tournaments/new" do
    it "비로그인 시 리다이렉트" do
      get new_club_tournament_path(club)
      expect(response).to redirect_to(new_session_path)
    end

    it "클럽 오너 접근 가능" do
      sign_in(owner)
      get new_club_tournament_path(club)
      expect(response).to have_http_status(:ok)
    end

    it "타인은 403" do
      sign_in(other)
      get new_club_tournament_path(club)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /clubs/:club_id/tournaments" do
    it "비로그인 시 리다이렉트" do
      post club_tournaments_path(club), params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "오너가 대회 생성" do
      sign_in(owner)
      expect {
        post club_tournaments_path(club), params: valid_params
      }.to change(Tournament, :count).by(1)
      expect(response).to redirect_to(tournament_path(Tournament.last))
    end

    it "매니저가 대회 생성" do
      sign_in(manager_user)
      expect {
        post club_tournaments_path(club), params: valid_params
      }.to change(Tournament, :count).by(1)
    end

    it "타인은 403" do
      sign_in(other)
      post club_tournaments_path(club), params: valid_params
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /tournaments/:id" do
    it "오너가 수정" do
      sign_in(owner)
      patch tournament_path(tournament), params: { tournament: { name: "변경된 대회" } }
      expect(tournament.reload.name).to eq("변경된 대회")
    end

    it "타인은 403" do
      sign_in(other)
      patch tournament_path(tournament), params: { tournament: { name: "변경" } }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /tournaments/:id" do
    it "오너가 draft 대회 삭제" do
      sign_in(owner)
      t = create(:tournament, club: club, status: :draft)
      expect {
        delete tournament_path(t)
      }.to change(Tournament, :count).by(-1)
    end

    it "진행 중 대회는 타인 삭제 불가" do
      sign_in(other)
      delete tournament_path(tournament)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /tournaments/:id/advance_status" do
    it "draft → in_progress 전환" do
      sign_in(owner)
      patch advance_status_tournament_path(tournament)
      expect(tournament.reload.status).to eq("in_progress")
    end
  end
end
