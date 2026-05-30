require "rails_helper"

RSpec.describe "Deck authoring", type: :system do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  describe "인라인 카드 편집 (CARD-03)" do
    it "행 클릭 → Turbo Frame 교체 → 저장 → read-only 행 복귀", js: true do
      pending("Wave 2: Capybara inline edit scenario"); raise
    end
  end
end
