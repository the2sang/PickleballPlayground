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
    end
  end

  describe "POST /decks (DECK-01)" do
    it "인증된 사용자가 personal 덱 생성 시 redirect" do
      sign_in(user)
      post decks_path, params: { deck: { title: "새 덱", description: "설명" } }
      deck = Deck.last
      expect(response).to redirect_to(deck_path(deck))
      expect(deck.scope).to eq("personal")
      expect(deck.owner).to eq(user)
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
