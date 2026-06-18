require "rails_helper"

RSpec.describe "Clubs", type: :request do
  before { host! "localhost" }

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

    it "클럽 오픈 게임 세션 목록과 접수 페이지 링크를 표시한다" do
      open_session = create(:game_session, :open_game, :with_court,
                            club: club,
                            title: "목요 오픈 게임")
      cancelled_session = create(:game_session, :open_game, :cancelled,
                                 club: club,
                                 title: "취소된 오픈 게임")

      get club_path(club)

      document = Nokogiri::HTML(response.body)
      link = document.at_css("a[href='#{club_open_sessions_path(club, open_session_id: open_session.id, anchor: "open_session_#{open_session.id}")}']")

      expect(response.body).to include("클럽 오픈 게임 세션")
      expect(response.body).to include("목요 오픈 게임")
      expect(response.body).to include("접수중")
      expect(response.body).not_to include(cancelled_session.title)
      expect(link).to be_present
    end

    it "비로그인 사용자에게 회원전용 오픈 게임 세션을 숨긴다" do
      public_session = create(:game_session, :open_game, club: club, title: "공개 오픈 게임")
      members_session = create(:game_session, :open_game, :members_only, club: club, title: "회원 오픈 게임")

      get club_path(club)

      expect(response.body).to include(public_session.title)
      expect(response.body).not_to include(members_session.title)
    end

    it "종료된 오픈 게임 세션도 대상 세션 링크로 표시한다" do
      ended_session = create(:game_session, :open_game, :with_court,
                             club: club,
                             title: "종료된 오픈 게임",
                             scheduled_date: Date.current - 1,
                             start_time: Time.zone.parse("09:00"),
                             end_time: Time.zone.parse("10:00"))

      get club_path(club)

      expect(response.body).to include("종료된 오픈 게임")
      expect(response.body).to include("종료")
      expect(response.body).to include(club_open_sessions_path(club, open_session_id: ended_session.id, anchor: "open_session_#{ended_session.id}"))
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

      it "즐겨찾기 버튼에 로그인 안내 토스트를 연결한다" do
        get clubs_path

        document = Nokogiri::HTML(response.body)
        favorite_button = document.at_css("button.cl-fav-btn[data-controller='login-required-toast']")

        expect(favorite_button).to be_present
        expect(favorite_button["data-login-required-toast-message-value"]).to eq("즐겨찾기는 로그인 후 활성화됩니다.")
        expect(favorite_button["data-action"]).to include("click->login-required-toast#show")
      end

      it "핫존 클럽명 오른쪽에 으뜸 아이콘을 표시한다" do
        approved_club.update!(hot_zone: true)

        get clubs_path

        document = Nokogiri::HTML(response.body)
        club_name = document.css(".cl-card__name").find { |node| node.text.include?(approved_club.name) }

        expect(club_name.at_css("i.fa-solid.fa-thumbs-up.cl-card__hot-zone-icon")).to be_present
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
  before { host! "localhost" }

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
