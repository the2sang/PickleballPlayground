require "rails_helper"

RSpec.describe "Decks", type: :request do
  let(:user) { create(:user) }

  describe "GET /decks (DECK-04, DECK-06, DECK-07)" do
    it "비인증 시 로그인 페이지로 리다이렉트" do
      pending("Wave 1: DecksController#index"); raise
    end

    it "0개 덱 사용자에게 빈 상태 hero 렌더 (DECK-07)" do
      pending("Wave 1: DecksController#index empty state"); raise
    end

    it "공식/클럽/개인 3섹션을 렌더 (DECK-04)" do
      pending("Wave 1: DecksController#index 3 sections"); raise
    end

    it "approved 클럽 멤버십이 없으면 클럽 섹션 숨김 (DECK-06)" do
      pending("Wave 1: club section conditional"); raise
    end

    it "유틸리티 nav dropdown에 '낱말카드' 링크 노출 (DECK-09)" do
      pending("Wave 1: application.html.erb nav update"); raise
    end
  end

  describe "POST /decks (DECK-01)" do
    it "인증된 사용자가 personal 덱 생성 시 redirect" do
      pending("Wave 1: DecksController#create"); raise
    end

    it "비인증 시 401/redirect" do
      pending("Wave 1: require_authentication"); raise
    end
  end

  describe "PATCH /decks/:id (DECK-02, DECK-07)" do
    it "본인 personal 덱 수정 성공" do
      pending("Wave 1: DecksController#update"); raise
    end

    it "타인 personal 덱 수정 시도 시 403" do
      pending("Wave 1: authorize @deck (personal_owner?)"); raise
    end
  end

  describe "DELETE /decks/:id (DECK-03)" do
    it "삭제 시 cards/card_reviews cascade" do
      pending("Wave 1: DecksController#destroy + dependent: :destroy"); raise
    end
  end
end
