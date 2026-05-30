require "rails_helper"

RSpec.describe "Clubs", type: :request do
  describe "GET /clubs/:id (클럽 상세)" do
    let(:club) { create(:club, status: :approved) }

    it "대회 섹션을 표시한다" do
      get club_path(club)
      expect(response.body).to include("대회")
    end

    it "비로그인 사용자에게 codedash 접속 버튼을 표시하지 않는다" do
      get club_path(club)
      expect(response.body).not_to include("codedash")
      expect(response.body).not_to include("code_dash_session")
    end

    it "클럽의 대회 목록을 표시한다" do
      tournament = create(:tournament, club: club, name: "봄 대회")
      get club_path(club)
      expect(response.body).to include("봄 대회")
    end

    context "클럽 매니저" do
      let(:manager) { create(:user) }
      before do
        create(:club_membership, club: club, user: manager, role: :manager, status: :approved)
        sign_in(manager)
      end

      it "새 대회 만들기 버튼을 표시한다" do
        get club_path(club)
        expect(response.body).to include(new_club_tournament_path(club))
      end
    end

    context "일반 사용자" do
      let(:user) { create(:user) }
      before { sign_in(user) }

      it "새 대회 만들기 버튼을 표시하지 않는다" do
        get club_path(club)
        expect(response.body).not_to include(new_club_tournament_path(club))
      end
    end
  end

  describe "GET /clubs" do
    let!(:approved_club)  { create(:club, status: :approved) }
    let!(:pending_club)   { create(:club, status: :pending) }
    let!(:suspended_club) { create(:club, status: :suspended) }

    context "비로그인 사용자" do
      it "유닛비 광고 링크 3개를 클럽 카드보다 먼저 표시한다" do
        get clubs_path

        document = Nokogiri::HTML(response.body)
        grid_items = document.css(".cl-grid > .cl-card-wrapper")
        ad_links = grid_items.first(3).map { |item| item.at_css("a.cl-ad-card") }

        expect(ad_links.compact.size).to eq(3)
        expect(ad_links.map { |link| link["href"] }).to all(eq("https://unit-b.co.kr"))
        expect(ad_links.map { |link| link.at_css("img.cl-ad-card__label")["alt"] }).to all(eq("유닛비 쇼핑몰"))
        expect(ad_links.map { |link| link.at_css("img.cl-ad-card__label")["width"] }).to all(eq("30"))
        expect(ad_links.map { |link| link.at_css("img.cl-ad-card__label")["height"] }).to all(eq("30"))
        expect(ad_links.map { |link| link.at_css("img.cl-ad-card__label")["src"] }).to all(include("unitb-icon"))
        expect(ad_links.map(&:text).join).to include("피클볼과 함께하는 유닛비…")
        styles = ad_links.map { |link| link["style"] }
        expect(styles[0]).to include("unitb-1")
        expect(styles[1]).to include("unitb-2")
        expect(styles[2]).to include("unitb-4")
        expect(grid_items[3].at_css(".cl-card__name").text).to include(approved_club.name)
      end

      it "승인된 클럽만 표시한다" do
        get clubs_path
        expect(response.body).to include(approved_club.name)
        expect(response.body).not_to include(pending_club.name)
        expect(response.body).not_to include(suspended_club.name)
      end
    end

    context "일반 사용자" do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it "승인된 클럽만 표시한다" do
        get clubs_path
        expect(response.body).to include(approved_club.name)
        expect(response.body).not_to include(pending_club.name)
        expect(response.body).not_to include(suspended_club.name)
      end
    end

    context "관리자" do
      let(:admin) { create(:user, :admin) }

      before { sign_in(admin) }

      it "공개 클럽 목록에서는 승인된 클럽만 표시한다" do
        get clubs_path
        expect(response.body).to include(approved_club.name)
        expect(response.body).not_to include(pending_club.name)
        expect(response.body).not_to include(suspended_club.name)
      end
    end
  end
end

RSpec.describe "GET /clubs/:id/manage (플래시카드 온보딩 넛지)", type: :request do
  let(:club)    { create(:club, status: :approved) }
  let(:manager) { create(:user) }

  before do
    create(:club_membership, club: club, user: manager, role: :manager, status: :approved)
    sign_in(manager)
  end

  context "덱이 없을 때" do
    it "넛지 배너를 표시한다" do
      get manage_club_path(club)
      expect(response.body).to include("플래시카드 덱을 만들어보세요!")
    end

    it "덱 만들기 링크를 포함한다" do
      get manage_club_path(club)
      expect(response.body).to include(new_deck_path)
      expect(response.body).to include("owner_id")
    end
  end

  context "클럽 덱이 있을 때" do
    before { create(:deck, scope: :club, owner: club) }

    it "넛지 배너를 표시하지 않는다" do
      get manage_club_path(club)
      expect(response.body).not_to include("플래시카드 덱을 만들어보세요!")
    end
  end
end
