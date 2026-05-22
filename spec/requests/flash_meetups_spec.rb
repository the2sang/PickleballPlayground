require "rails_helper"

RSpec.describe "FlashMeetups", type: :request do
  let(:user)     { create(:user, :profile_complete) }
  let(:other)    { create(:user, :profile_complete) }
  let(:meetup)   { create(:flash_meetup, user: user) }
  let(:valid_params) do
    { flash_meetup: { venue_name: "테스트 코트", scheduled_at: 2.days.from_now,
                      ends_at: 2.days.from_now + 2.hours,
                      gender_filter: "all_genders", level_filter: "all_levels",
                      allowed_age_groups: [] } }
  end

  describe "GET /flash_meetups" do
    it "비로그인 사용자도 접근 가능" do
      get flash_meetups_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /flash_meetups/:id" do
    it "비로그인 사용자도 접근 가능" do
      get flash_meetup_path(meetup)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /flash_meetups/new" do
    it "비로그인 시 리다이렉트" do
      get new_flash_meetup_path
      expect(response).to redirect_to(new_session_path)
    end

    it "로그인 시 접근 가능" do
      sign_in(user)
      get new_flash_meetup_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /flash_meetups" do
    it "비로그인 시 리다이렉트" do
      post flash_meetups_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "로그인 시 모임 생성" do
      sign_in(user)
      expect {
        post flash_meetups_path, params: valid_params
      }.to change(FlashMeetup, :count).by(1)
      expect(response).to redirect_to(flash_meetup_path(FlashMeetup.last))
    end

    it "유효하지 않은 파라미터는 new 렌더링" do
      sign_in(user)
      post flash_meetups_path, params: { flash_meetup: { venue_name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /flash_meetups/:id" do
    it "개설자가 아닌 사용자는 403" do
      sign_in(other)
      patch flash_meetup_path(meetup), params: valid_params
      expect(response).to have_http_status(:redirect)
    end

    it "개설자는 수정 가능" do
      sign_in(user)
      patch flash_meetup_path(meetup), params: { flash_meetup: { venue_name: "새 코트" } }
      expect(meetup.reload.venue_name).to eq("새 코트")
    end
  end

  describe "DELETE /flash_meetups/:id" do
    it "개설자는 삭제 가능" do
      meetup_id = meetup.id
      sign_in(user)
      expect {
        delete flash_meetup_path(meetup)
      }.to change(FlashMeetup, :count).by(-1)
      expect(response).to redirect_to(flash_meetups_path)
    end

    it "타인은 삭제 불가" do
      sign_in(other)
      delete flash_meetup_path(meetup)
      expect(FlashMeetup.exists?(meetup.id)).to be true
    end
  end
end
