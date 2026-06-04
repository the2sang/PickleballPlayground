require "rails_helper"

RSpec.describe "FlashMeetups", type: :request do
  let(:user)     { create(:user, :profile_complete) }
  let(:other)    { create(:user, :profile_complete) }
  let(:meetup)   { create(:flash_meetup, user: user) }
  let(:valid_params) do
    { flash_meetup: { venue_name: "테스트 코트",
                      start_date: 2.days.from_now.to_date.to_s,
                      end_date: 2.days.from_now.to_date.to_s,
                      start_time: "10:00",
                      end_time: "12:00",
                      gender_filter: "all_genders", level_filter: "all_levels",
                      hot_zone: "0",
                      allowed_age_groups: [] } }
  end

  describe "GET /flash_meetups" do
    it "비로그인 사용자도 접근 가능" do
      get flash_meetups_path
      expect(response).to have_http_status(:ok)
    end

    it "핫존 운동모임은 장소명 오른쪽에 핫존 아이콘을 표시한다" do
      meetup.update!(hot_zone: true)

      get flash_meetups_path

      document = Nokogiri::HTML(response.body)
      title = document.css(".cl-list-item__title").find { |node| node.text.include?(meetup.venue_name) }

      expect(title.at_css("i.fa-solid.fa-thumbs-up.cl-list-item__hot-zone-icon")).to be_present
    end
  end

  describe "GET /flash_meetups/:id" do
    it "비로그인 사용자도 접근 가능" do
      get flash_meetup_path(meetup)
      expect(response).to have_http_status(:ok)
    end

    it "주소가 있으면 네이버 지도 연동 링크로 표시한다" do
      meetup.update!(address: "서울시 송파구 올림픽로 424")

      get flash_meetup_path(meetup)

      document = Nokogiri::HTML(response.body)
      link = document.at_css("a.cl-map-address-link")

      expect(link).to be_present
      expect(link.text).to eq("서울시 송파구 올림픽로 424")
      expect(link["href"]).to include("https://map.naver.com/p/search/")
      expect(link["data-controller"]).to eq("naver-map")
      expect(link["data-action"]).to include("click->naver-map#open")
      expect(link["data-naver-map-query-value"]).to eq("서울시 송파구 올림픽로 424")
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
      expect(FlashMeetup.last.start_date).to eq(2.days.from_now.to_date)
      expect(FlashMeetup.last.start_time.strftime("%H:%M")).to eq("10:00")
      expect(response).to redirect_to(flash_meetup_path(FlashMeetup.last))
    end

    it "시간 없이 날짜만으로 모임 생성" do
      sign_in(user)
      params = valid_params.deep_dup
      params[:flash_meetup][:start_time] = ""
      params[:flash_meetup][:end_time] = ""

      expect {
        post flash_meetups_path, params: params
      }.to change(FlashMeetup, :count).by(1)

      created = FlashMeetup.last
      expect(created.start_date).to eq(2.days.from_now.to_date)
      expect(created.end_date).to eq(2.days.from_now.to_date)
      expect(created.start_time).to be_nil
      expect(created.end_time).to be_nil
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

    it "개설자는 핫존 설정을 수정할 수 있다" do
      sign_in(user)
      patch flash_meetup_path(meetup), params: { flash_meetup: { hot_zone: "1" } }
      expect(meetup.reload).to be_hot_zone
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
