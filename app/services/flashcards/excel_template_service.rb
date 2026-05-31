require "caxlsx"

module Flashcards
  class ExcelTemplateService
    CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    Template = Data.define(:filename, :content_type, :data)

    def self.call(kind:) = new(kind: kind).call

    def initialize(kind:)
      @kind = kind.to_s
    end

    def call
      package = Axlsx::Package.new
      workbook = package.workbook
      styles = workbook.styles
      header_style = styles.add_style(bg_color: "111827", fg_color: "FFFFFF", b: true, alignment: { horizontal: :center })
      note_style = styles.add_style(fg_color: "4B5563", alignment: { wrap_text: true })

      add_guide_sheet(workbook, note_style)
      case @kind
      when "objective"
        add_data_sheet(workbook, "객관식", objective_headers, header_style)
        filename = "card-deck-objective-template.xlsx"
      else
        add_data_sheet(workbook, "주관식", subjective_headers, header_style)
        filename = "card-deck-subjective-template.xlsx"
      end

      Template.new(filename: filename, content_type: CONTENT_TYPE, data: package.to_stream.read)
    end

    private

    def subjective_headers
      [ "덱 제목", "덱 설명", "분류코드", "문제", "정답", "힌트", "태그" ]
    end

    def objective_headers
      [ "덱 제목", "덱 설명", "분류코드", "문제", "정답", "오답1", "오답2", "오답3", "해설", "태그" ]
    end

    def add_guide_sheet(workbook, note_style)
      workbook.add_worksheet(name: "작성 가이드") do |sheet|
        sheet.add_row [ "카드 덱 엑셀 업로드 작성 가이드" ]
        sheet.add_row [ "1행은 헤더로 유지하고, 2행부터 카드를 입력하세요." ], style: note_style
        sheet.add_row [ "덱 제목은 첫 카드 행에 반드시 입력하세요. 아래 행이 비어 있으면 직전 덱 제목을 이어받습니다." ], style: note_style
        sheet.add_row [ "분류코드는 덱마다 하나만 입력합니다. 1 정치/경제, 2 사회/역사, 3 과학/기술, 4 스포츠/예술, 5 언어, 6 기타" ], style: note_style
        sheet.add_row [ "주관식 시트: 덱 제목, 덱 설명, 분류코드, 문제, 정답, 힌트, 태그" ], style: note_style
        sheet.add_row [ "객관식 시트: 덱 제목, 덱 설명, 분류코드, 문제, 정답, 오답1, 오답2, 오답3, 해설, 태그" ], style: note_style
        sheet.add_row [ "태그는 쉼표로 구분하세요. 예: 경제,금리,기초" ], style: note_style
        sheet.column_widths 44
      end
    end

    def add_data_sheet(workbook, name, headers, header_style)
      workbook.add_worksheet(name: name) do |sheet|
        sheet.add_row headers, style: Array.new(headers.size, header_style)
        sheet.add_row Array.new(headers.size, nil)
        sheet.column_widths(*headers.map { |header| header == "문제" ? 42 : 18 })
      end
    end
  end
end
