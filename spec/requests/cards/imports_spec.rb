require "rails_helper"

RSpec.describe "Cards::Imports", type: :request do
  let(:user)  { create(:user) }
  let(:deck)  { create(:deck, scope: :personal, owner: user) }
  let(:other) { create(:user) }

  def sign_in(u)
    post session_path, params: { email_address: u.email_address, password: "password" }
  end

  describe "GET /decks/:deck_id/cards/imports/new (CARD-05)" do
    it "인증된 소유자는 새 import 폼을 볼 수 있다" do
      sign_in(user)
      get new_deck_cards_imports_path(deck)
      expect(response).to have_http_status(:ok)
    end

    it "비로그인 시 리다이렉트" do
      get new_deck_cards_imports_path(deck)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /decks/:deck_id/cards/imports (CARD-05)" do
    it "preview 모드 — 파싱 결과 반환" do
      sign_in(user)
      post deck_cards_imports_path(deck),
           params:  { text: "사과\t apple", separator: "tab", mode: "preview" },
           headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, */*" }

      expect(response).to have_http_status(:ok)
    end

    it "save 모드 — 정상 입력 시 카드 일괄 생성" do
      sign_in(user)
      expect {
        post deck_cards_imports_path(deck),
             params: { text: "front1\tback1\nfront2\tback2", separator: "tab", commit: "저장" }
      }.to change { deck.cards.count }.by(2)

      expect(response).to redirect_to(deck_path(deck))
    end

    it "front 중복 시 저장 차단 (전체 롤백)" do
      create(:card, deck: deck, front: "기존앞면", back: "기존뒷면")
      sign_in(user)

      expect {
        post deck_cards_imports_path(deck),
             params:  { text: "기존앞면\t새뒷면", separator: "tab", commit: "저장" },
             headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, */*" }
      }.not_to change { deck.cards.count }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "구분자 충돌 시 저장 차단" do
      sign_in(user)
      # 탭 구분자가 front 안에 포함되면 importable? = false
      expect {
        post deck_cards_imports_path(deck),
             params:  { text: "앞\t안에탭\t있음", separator: "tab", commit: "저장" },
             headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, */*" }
      }.not_to change { deck.cards.count }
    end

    it "비소유자 접근 시 403" do
      sign_in(other)
      post deck_cards_imports_path(deck),
           params: { text: "a\tb", separator: "tab", commit: "저장" }

      expect(response).to have_http_status(:forbidden).or have_http_status(:not_found)
    end
  end
end
