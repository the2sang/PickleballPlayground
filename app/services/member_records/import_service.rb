module MemberRecords
  class ImportService
    IMPORT_LIMIT = 500
    Result = Struct.new(:imported, :skipped, :errors, keyword_init: true)

    def self.call(file:)
      new(file).call
    end

    def initialize(file)
      @file = file
    end

    def call
      imported = 0
      skipped  = 0
      errors   = []

      spreadsheet = Roo::Spreadsheet.open(@file.path, extension: :xlsx)
      rows = spreadsheet.sheet(0).parse(headers: true).drop(1).first(IMPORT_LIMIT)

      rows.each_with_index do |row, idx|
        line = idx + 2
        agreed = row["개인정보수집동의(Y/N)"].to_s.strip.upcase
        unless agreed == "Y"
          skipped += 1
          next
        end

        record = MemberRecord.new(
          name:                  row["이름"].to_s.strip,
          club_name:             row["소속클럽"].to_s.strip,
          gender:                row["성별"].to_s.strip,
          birth_date:            parse_date(row["생년월일(yyyy-mm-dd)"]),
          phone:                 row["연락처"].to_s.strip,
          pickleball_started_at: parse_ym(row["피클볼시작일(yyyy-mm)"]),
          club_joined_at:        parse_ym(row["클럽가입시기(yyyy-mm)"]),
          address:               row["주소"].to_s.strip,
          privacy_agreed:        true
        )

        if record.save
          imported += 1
        else
          errors << "#{line}행: #{record.errors.full_messages.join(', ')}"
        end
      end

      Result.new(imported: imported, skipped: skipped, errors: errors)
    end

    private

    def parse_date(value)
      Date.parse(value.to_s.strip)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_ym(value)
      str = value.to_s.strip
      return nil if str.blank?
      Date.strptime(str, "%Y-%m")
    rescue ArgumentError, TypeError
      nil
    end
  end
end
