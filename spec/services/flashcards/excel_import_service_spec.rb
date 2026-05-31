require "rails_helper"
require "caxlsx"

RSpec.describe Flashcards::ExcelImportService do
  let(:user) { create(:user) }

  def build_workbook(path)
    package = Axlsx::Package.new
    workbook = package.workbook
    workbook.add_worksheet(name: "주관식") do |sheet|
      sheet.add_row [ "덱 제목", "덱 설명", "문제", "정답", "힌트", "태그" ]
      sheet.add_row [ "경제 상식", "직장인 경제 기본", "중앙은행 기준 정책금리는?", "기준금리", "금리 뉴스 핵심", "경제,금리" ]
      sheet.add_row [ nil, nil, "물가가 지속적으로 오르는 현상은?", "인플레이션", nil, "경제,물가" ]
    end
    workbook.add_worksheet(name: "객관식") do |sheet|
      sheet.add_row [ "덱 제목", "덱 설명", "문제", "정답", "오답1", "오답2", "오답3", "해설", "태그" ]
      sheet.add_row [ "객관식 경제", "경제 객관식", "수출액에서 수입액을 뺀 값은?", "무역수지", "경상수지", "기준금리", "소비자물가지수", "상품 거래 차이", "경제,무역" ]
    end
    package.serialize(path)
  end

  it "주관식/객관식 시트를 읽어 개인 덱과 카드를 만든다" do
    Tempfile.create([ "flashcards", ".xlsx" ]) do |file|
      build_workbook(file.path)

      result = described_class.call(file: file, user: user)

      expect(result).to be_success
      expect(result.decks.map(&:title)).to contain_exactly("경제 상식", "객관식 경제")
      expect(result.cards_count).to eq(3)

      subjective = Deck.find_by!(title: "경제 상식")
      objective = Deck.find_by!(title: "객관식 경제")
      expect(subjective.owner).to eq(user)
      expect(subjective.cards.count).to eq(2)
      expect(subjective.cards.first).to be_basic
      expect(objective.cards.first).to be_multiple_choice
      expect(objective.cards.first.answer_choices).to contain_exactly("경상수지", "기준금리", "소비자물가지수")
    end
  end

  it "객관식 오답 선택지가 부족하면 저장하지 않는다" do
    Tempfile.create([ "flashcards", ".xlsx" ]) do |file|
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "객관식") do |sheet|
        sheet.add_row [ "덱 제목", "덱 설명", "문제", "정답", "오답1", "오답2", "오답3", "해설", "태그" ]
        sheet.add_row [ "불완전 덱", nil, "문제", "정답", "오답", nil, nil, nil, nil ]
      end
      package.serialize(file.path)

      result = described_class.call(file: file, user: user)

      expect(result).to be_failure
      expect(result.errors.join).to include("오답2")
      expect(Deck.where(title: "불완전 덱")).to be_empty
    end
  end
end
