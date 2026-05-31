require "rails_helper"

RSpec.describe "Decks", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /decks (DECK-04, DECK-06, DECK-07)" do
    context "비인증 사용자" do
      before { create(:deck, :official) }

      it "공식 섹션을 렌더하고 200 반환" do
        get decks_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("공식")
      end
    end

    context "인증된 사용자 — 0개 personal 덱" do
      before { sign_in(user) }

      it "0개 덱 사용자에게 빈 상태 hero 렌더 (DECK-07)" do
        get decks_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("낱말카드로 학습을 시작해 보세요")
      end
    end

    context "인증된 사용자 — personal 덱 보유" do
      before do
        sign_in(user)
        create(:deck, :personal, owner: user)
        3.times { create(:deck, :official) }
      end

      it "공식/개인 3섹션을 렌더 (DECK-04)" do
        get decks_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("공식")
        expect(response.body).to include("내 덱")
      end

      it "분류 select로 해당 분류의 덱만 표시한다" do
        economic = create(:deck, :official, title: "경제 덱", category: :politics_economy)
        create(:card, deck: economic)
        sports = create(:deck, :official, title: "스포츠 덱", category: :sports_arts)
        create(:card, deck: sports)

        get decks_path(category: Deck.categories[:politics_economy])

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("분류")
        expect(response.body).to include("경제 덱")
        expect(response.body).not_to include("스포츠 덱")
      end

      it "허브 헤더에 엑셀 양식 다운로드와 카드 덱 업로드 폼을 노출한다" do
        get decks_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("주관식 양식")
        expect(response.body).to include("객관식 양식")
        expect(response.body).to include("카드 덱 업로드")
        expect(response.body).to include(deck_upload_template_path(kind: "subjective"))
        expect(response.body).to include(deck_upload_template_path(kind: "objective"))
        expect(response.body).to include(deck_uploads_path)
      end

      it "한도에 도달하면 덱 추가 승인요청 버튼을 노출한다" do
        Deck.where(scope: :personal, owner: user).destroy_all
        Deck::PERSONAL_DECK_LIMIT.times { |index| create(:deck, :personal, owner: user, title: "내 덱 #{index}") }

        get decks_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("내 덱 #{Deck::PERSONAL_DECK_LIMIT}/#{Deck::PERSONAL_DECK_LIMIT}")
        expect(response.body).to include("덱 추가 승인요청")
        expect(response.body).to include(deck_addition_requests_path)
      end
    end

    context "approved 클럽 멤버십 없는 사용자" do
      before { sign_in(user) }

      it "클럽 섹션 숨김 (DECK-06)" do
        get decks_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("클럽 덱")
      end
    end

    it "유틸리티 nav dropdown에 '낱말카드' 링크 노출 (DECK-09)" do
      get decks_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("낱말카드")
    end

    it "덱 카드 액션에 주관식 학습 링크를 노출한다" do
      deck = create(:deck, :official)
      create(:card, deck: deck)

      get decks_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("카드보기")
      expect(response.body).to include("주관식")
      expect(response.body).to include(deck_flip_path(deck))
    end
  end

  describe "GET /decks/:id" do
    it "주관식 학습 메뉴에 별3개 이상만 필터 링크를 노출한다" do
      sign_in(user)
      deck = create(:deck, :personal, owner: user)
      create(:card, deck: deck)

      get deck_path(deck)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("주관식 학습")
      expect(response.body).to include("별3개 이상만")
      expect(response.body).to include(deck_flip_path(deck, min_stars: 3))
    end
  end

  describe "GET /decks/new" do
    it "비인증 시 로그인 페이지로 리다이렉트" do
      get new_deck_path
      expect(response).to redirect_to(new_session_path)
    end

    it "인증된 사용자는 new 폼 렌더" do
      sign_in(user)
      get new_deck_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("분류")
      expect(response.body).to include("1. 정치/경제")
    end
  end

  describe "POST /decks (DECK-01)" do
    it "인증된 사용자가 personal 덱 생성 시 redirect" do
      sign_in(user)
      post decks_path, params: {
        deck: { title: "새 덱", description: "설명", category: Deck.categories[:science_technology] }
      }
      deck = Deck.last
      expect(response).to redirect_to(deck_path(deck))
      expect(deck.scope).to eq("personal")
      expect(deck.owner).to eq(user)
      expect(deck).to be_science_technology
    end

    it "개인 덱 한도를 넘으면 생성을 막는다" do
      sign_in(user)
      Deck::PERSONAL_DECK_LIMIT.times { |index| create(:deck, :personal, owner: user, title: "덱 #{index}") }

      expect {
        post decks_path, params: { deck: { title: "초과 덱" } }
      }.not_to change(Deck, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("덱 추가 승인요청")
    end

    it "비인증 시 로그인 페이지로 리다이렉트" do
      post decks_path, params: { deck: { title: "새 덱" } }
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PATCH /decks/:id (DECK-02, DECK-07)" do
    let!(:deck) { create(:deck, :personal, owner: user) }

    it "본인 personal 덱 수정 성공" do
      sign_in(user)
      patch deck_path(deck), params: { deck: { title: "수정된 제목" } }
      expect(response).to redirect_to(deck_path(deck))
      expect(deck.reload.title).to eq("수정된 제목")
    end

    it "타인 personal 덱 수정 시도 시 redirect (Pundit NotAuthorized)" do
      sign_in(other_user)
      patch deck_path(deck), params: { deck: { title: "해킹" } }
      expect(response).to redirect_to(root_path)
      expect(deck.reload.title).not_to eq("해킹")
    end
  end

  describe "DELETE /decks/:id (DECK-03)" do
    it "삭제 시 cards cascade" do
      sign_in(user)
      deck = create(:deck, :personal, owner: user)
      card = create(:card, deck: deck, front: "앞면", back: "뒷면", position: 0)
      delete deck_path(deck)
      expect(response).to redirect_to(decks_path)
      expect { deck.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { card.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Phase 4: club deck creation" do
    let(:club)  { create(:club) }

    context "approved club member creates club deck" do
      before do
        create(:club_membership, club: club, user: user, status: :approved)
        sign_in(user)
      end

      it "creates club deck owned by the club" do
        post decks_path, params: {
          deck: { title: "클럽 덱", description: "설명", scope: "club", owner_id: club.id, owner_type: "Club" }
        }
        deck = Deck.last
        expect(deck.club?).to be true
        expect(deck.owner).to eq(club)
        expect(deck.title).to eq("클럽 덱")
        expect(response).to redirect_to(deck_path(deck))
      end
    end

    context "non-member attempts to create club deck" do
      before { sign_in(user) }

      it "is rejected with alert" do
        post decks_path, params: {
          deck: { title: "해킹 덱", scope: "club", owner_id: club.id, owner_type: "Club" }
        }
        expect(response).to have_http_status(:found)
        expect(flash[:alert]).to be_present
        expect(Deck.where(title: "해킹 덱")).to be_empty
      end
    end

    context "mass assignment: scope/owner cannot be set to official via params" do
      before { sign_in(user) }

      it "ignores scope=official override and creates personal deck" do
        post decks_path, params: { deck: { title: "공식인 척 덱", scope: "official" } }
        deck = Deck.last
        expect(deck.personal?).to be true
      end
    end
  end
end
