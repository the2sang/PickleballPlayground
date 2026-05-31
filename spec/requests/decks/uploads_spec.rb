require "rails_helper"
require "caxlsx"

RSpec.describe "Deck workbook uploads", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  def write_subjective_workbook(path)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "주관식") do |sheet|
      sheet.add_row [ "덱 제목", "덱 설명", "분류코드", "문제", "정답", "힌트", "태그" ]
      sheet.add_row [ "업로드 덱", "엑셀 업로드 테스트", 4, "피클볼 서브는 어느 방향?", "대각선", "반대편 서비스 코트", "피클볼,서브" ]
    end
    package.serialize(path)
  end

  def write_multi_deck_workbook(path, count)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "주관식") do |sheet|
      sheet.add_row [ "덱 제목", "덱 설명", "분류코드", "문제", "정답", "힌트", "태그" ]
      count.times do |index|
        sheet.add_row [ "업로드 덱 #{index}", "설명", 6, "문제 #{index}", "정답 #{index}", nil, nil ]
      end
    end
    package.serialize(path)
  end

  describe "GET /deck_uploads/templates/:kind" do
    it "주관식 엑셀 양식을 다운로드한다" do
      get deck_upload_template_path(kind: "subjective")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Flashcards::ExcelTemplateService::CONTENT_TYPE)
      expect(response.body).to start_with("PK")
    end

    it "객관식 엑셀 양식을 다운로드한다" do
      get deck_upload_template_path(kind: "objective")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("card-deck-objective-template.xlsx")
    end
  end

  describe "POST /deck_uploads" do
    it "엑셀 파일로 내 덱을 만든다" do
      Tempfile.create([ "deck-upload", ".xlsx" ]) do |file|
        write_subjective_workbook(file.path)
        upload = Rack::Test::UploadedFile.new(
          file.path,
          Flashcards::ExcelTemplateService::CONTENT_TYPE
        )

        post deck_uploads_path, params: { file: upload }
      end

      deck = Deck.find_by!(title: "업로드 덱")
      expect(response).to redirect_to(decks_path)
      expect(deck.owner).to eq(user)
      expect(deck).to be_personal
      expect(deck).to be_sports_arts
      expect(deck.cards.first.front).to eq("피클볼 서브는 어느 방향?")
      expect(deck.cards.first.back).to eq("대각선")
    end

    it "1MB를 초과한 업로드 파일을 거절한다" do
      Tempfile.create([ "deck-upload-large", ".xlsx" ]) do |file|
        file.write("x" * (Deck::PERSONAL_DECK_SIZE_LIMIT_BYTES + 1))
        file.rewind
        upload = Rack::Test::UploadedFile.new(
          file.path,
          Flashcards::ExcelTemplateService::CONTENT_TYPE
        )

        post deck_uploads_path, params: { file: upload }
      end

      expect(response).to redirect_to(decks_path)
      expect(flash[:alert]).to include("1MB")
    end

    it "남은 개인 덱 한도를 초과하는 업로드를 거절한다" do
      Deck::PERSONAL_DECK_LIMIT.times { |index| create(:deck, :personal, owner: user, title: "기존 덱 #{index}") }

      Tempfile.create([ "deck-upload-over-limit", ".xlsx" ]) do |file|
        write_multi_deck_workbook(file.path, 1)
        upload = Rack::Test::UploadedFile.new(
          file.path,
          Flashcards::ExcelTemplateService::CONTENT_TYPE
        )

        expect {
          post deck_uploads_path, params: { file: upload }
        }.not_to change(Deck, :count)
      end

      expect(response).to redirect_to(decks_path)
      expect(flash[:alert]).to include("덱 추가 승인요청")
    end
  end
end
