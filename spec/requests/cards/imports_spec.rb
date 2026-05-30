require "rails_helper"

RSpec.describe "Cards::Imports", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  describe "POST /decks/:deck_id/cards/imports (CARD-05)" do
    it "preview 모드 — 파싱 결과 반환" do
      pending("Wave 3: Cards::ImportsController#create preview"); raise
    end

    it "save 모드 — 정상 입력 시 카드 일괄 생성" do
      pending("Wave 3: Cards::ImportsController#create save"); raise
    end

    it "front 중복 시 저장 차단 (전체 롤백)" do
      pending("Wave 3: PasteImportService duplicate front guard"); raise
    end

    it "구분자 충돌 시 저장 차단" do
      pending("Wave 3: PasteImportService separator collision"); raise
    end

    it "비소유자 접근 시 403" do
      pending("Wave 3: authorize @deck, :update?"); raise
    end
  end
end
