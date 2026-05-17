module MemberRecords
  class TemplateService
    def self.call
      package = Axlsx::Package.new
      wb = package.workbook

      wb.add_worksheet(name: "회원명부") do |sheet|
        header_style = wb.styles.add_style(
          bg_color: "4CAF50", fg_color: "FFFFFF",
          b: true, alignment: { horizontal: :center }
        )
        sheet.add_row MemberRecord::EXCEL_HEADERS, style: header_style

        sheet.add_row [
          "홍길동", "마북", "남", "1990-01-15",
          "010-1234-5678", "2023-03", "2023-06",
          "경기도 용인시 수지구", "Y"
        ]

        sheet.column_widths 15, 12, 8, 18, 16, 18, 18, 30, 20
      end

      package.to_stream.read
    end
  end
end
