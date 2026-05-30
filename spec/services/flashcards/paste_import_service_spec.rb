require "rails_helper"

RSpec.describe "Flashcards::PasteImportService" do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  describe ".call (preview 모드)" do
    it "탭 구분자 입력 파싱" do
      pending("Wave 3: PasteImportService preview parse"); raise
    end

    it "빈 줄 skip" do
      pending("Wave 3: blank line filter"); raise
    end

    it "필수 필드(front/back) 미달 줄 경고" do
      pending("Wave 3: row-level warnings"); raise
    end

    it "구분자가 필드 내부에 포함된 줄을 경고로 표시" do
      pending("Wave 3: separator collision detection"); raise
    end
  end

  describe ".call (save 모드)" do
    it "IMPORT_LIMIT(500) 초과 입력 거부" do
      pending("Wave 3: IMPORT_LIMIT enforcement"); raise
    end

    it "정상 입력 시 트랜잭션 안에서 일괄 저장" do
      pending("Wave 3: transactional save"); raise
    end

    it "한 카드 저장 실패 시 전체 롤백" do
      pending("Wave 3: transaction rollback on RecordInvalid"); raise
    end

    it "덱 내 front 중복 검출 시 저장 차단" do
      pending("Wave 3: duplicate-front guard"); raise
    end
  end
end
