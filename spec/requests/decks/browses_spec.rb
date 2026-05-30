require "rails_helper"

RSpec.describe "Decks::Browses", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }

  describe "GET /decks/:deck_id/browse" do
    context "본인 personal 덱" do
      before do
        @card1 = create(:card, deck: deck, front: "프론트1", back: "백1", hint: "힌트1")
        @card2 = create(:card, deck: deck, front: "프론트2", back: "백2", hint: "힌트2")
        sign_in(user)
      end

      it "browse 페이지를 렌더하고 카드 JSON을 data-attribute로 전달한다" do
        get deck_browse_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-controller=\"browse\"")
        expect(response.body).to include("data-browse-cards-value=")
      end

      it "JSON에 id/front/back만 포함하고 hint/tags/card_type/deck_id는 누수하지 않는다 (T-03-Disclose)" do
        get deck_browse_path(deck)
        # data-browse-cards-value의 HTML escape 풀어서 JSON parse
        match = response.body.match(/data-browse-cards-value="([^"]*)"/)
        expect(match).to be_present
        json_str = CGI.unescapeHTML(match[1])
        cards = JSON.parse(json_str)
        expect(cards.size).to eq(2)
        expect(cards.first.keys).to contain_exactly("id", "front", "back")
        expect(cards.first).not_to have_key("hint")
        expect(cards.first).not_to have_key("tags")
        expect(cards.first).not_to have_key("card_type")
        expect(cards.first).not_to have_key("deck_id")
      end

      it "CardReview를 생성하지 않는다 (BROWSE-04 / T-03-Browse)" do
        expect {
          get deck_browse_path(deck)
        }.not_to change(CardReview, :count)
      end
    end

    context "빈 덱 (카드 없음)" do
      before { sign_in(user) }

      it "Browse 빈 상태 메시지 렌더" do
        get deck_browse_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("이 덱에 카드가 없습니다")
        expect(response.body).not_to include("data-controller=\"browse\"")
      end
    end

    context "타 사용자 personal 덱" do
      let(:other) { create(:user) }
      let(:foreign_deck) { create(:deck, :personal, owner: other) }
      before do
        create(:card, deck: foreign_deck)
        sign_in(user)
      end

      it "DeckPolicy가 차단" do
        get deck_browse_path(foreign_deck)
        expect(response).to redirect_to(root_path).or have_http_status(:forbidden)
      end
    end

    context "official 덱" do
      let(:official_deck) { create(:deck, :official) }
      before do
        create(:card, deck: official_deck)
        sign_in(user)
      end

      it "어느 사용자나 browse 가능" do
        get deck_browse_path(official_deck)
        expect(response).to have_http_status(:ok)
      end
    end

    context "비인증 사용자" do
      it "로그인 페이지로 리다이렉트" do
        get deck_browse_path(deck)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "GET /decks/:deck_id (entry points)" do
    context "카드가 있는 덱" do
      before do
        create(:card, deck: deck)
        sign_in(user)
      end

      it "훑어보기 링크가 deck_browse_path로 렌더된다" do
        get deck_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("decks/#{deck.id}/browse")
      end

      it "훑어보기 텍스트가 보인다" do
        get deck_path(deck)
        expect(response.body).to include("훑어보기")
      end
    end

    context "카드가 없는 덱" do
      before { sign_in(user) }

      it "훑어보기 링크가 없다" do
        get deck_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("decks/#{deck.id}/browse")
      end
    end
  end
end
