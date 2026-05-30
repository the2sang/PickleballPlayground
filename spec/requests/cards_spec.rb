require "rails_helper"

RSpec.describe "Cards", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  describe "POST /decks/:deck_id/cards (CARD-01)" do
    it "본인 덱에 카드 생성" do
      pending("Wave 2: CardsController#create"); raise
    end

    it "비인증 시 401/redirect" do
      pending("Wave 2: auth gate"); raise
    end

    it "front_image 파라미터를 무시한다 (CARD-06, T-02-03)" do
      pending("Wave 2: strong params excludes front_image/back_image"); raise
    end
  end

  describe "PATCH /decks/:deck_id/cards/:id (CARD-03)" do
    it "본인 덱 카드 수정 시 Turbo Stream으로 행 교체" do
      pending("Wave 2: CardsController#update + turbo_stream"); raise
    end

    it "타인 덱 카드 수정 시도 시 403" do
      pending("Wave 2: authorize @card"); raise
    end
  end

  describe "DELETE /decks/:deck_id/cards/:id (CARD-04)" do
    it "본인 덱 카드 삭제 + CardReview cascade" do
      pending("Wave 2: CardsController#destroy"); raise
    end
  end
end
