require "csv"

module MemberRecords
  class TemplateService
    def self.call
      CSV.generate(encoding: "UTF-8") do |csv|
        csv << MemberRecord::EXCEL_HEADERS
        csv << [
          "홍길동", "마북", "남", "1990-01-15",
          "010-1234-5678", "2023-03", "2023-06",
          "경기도 용인시 수지구", "Y"
        ]
      end
    end
  end
end
