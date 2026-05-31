require "roo"

module Flashcards
  class ExcelImportService
    IMPORT_LIMIT = 500

    Result = Data.define(:success?, :decks, :cards_count, :errors) do
      def failure? = !success?
    end

    HeaderConfig = Data.define(:card_type, :headers)

    HEADER_CONFIGS = {
      "주관식" => HeaderConfig.new(
        card_type: :basic,
        headers: {
          deck_title: "덱 제목",
          deck_description: "덱 설명",
          category: "분류코드",
          front: "문제",
          back: "정답",
          hint: "힌트",
          tags: "태그"
        }
      ),
      "객관식" => HeaderConfig.new(
        card_type: :multiple_choice,
        headers: {
          deck_title: "덱 제목",
          deck_description: "덱 설명",
          category: "분류코드",
          front: "문제",
          back: "정답",
          wrong_1: "오답1",
          wrong_2: "오답2",
          wrong_3: "오답3",
          hint: "해설",
          tags: "태그"
        }
      )
    }.freeze

    def self.call(**args) = new(**args).call

    def initialize(file:, user:)
      @file = file
      @user = user
      @errors = []
    end

    def call
      return failure("업로드할 엑셀 파일을 선택해 주세요.") if @file.blank?
      return failure("사용자 정의 덱 1개당 업로드 파일 크기는 최대 1MB입니다.") if file_size > Deck::PERSONAL_DECK_SIZE_LIMIT_BYTES

      workbook = Roo::Excelx.new(file_path)
      groups = parse_workbook(workbook)
      return failure("가져올 카드가 없습니다. 주관식 또는 객관식 시트에 카드를 입력해 주세요.") if groups.empty? && @errors.empty?
      return failure(@errors) if @errors.any?
      return failure(deck_limit_error) unless @user.can_create_personal_decks?(groups.size)

      decks = save_groups!(groups)
      Flashcards::DueCountCacheService.invalidate(@user)
      Result.new(success?: true, decks: decks, cards_count: decks.sum { |deck| deck.cards.size }, errors: [])
    rescue Zip::Error, Roo::FileNotFound, ArgumentError => e
      failure("엑셀 파일을 읽을 수 없습니다: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure("저장 실패: #{e.record.errors.full_messages.to_sentence}")
    end

    private

    def file_path
      @file.respond_to?(:path) ? @file.path : @file.tempfile.path
    end

    def file_size
      if @file.respond_to?(:size)
        @file.size
      else
        @file.tempfile.size
      end.to_i
    end

    def parse_workbook(workbook)
      groups = {}
      total_cards = 0

      workbook.sheets.each do |sheet_name|
        config = sheet_config(sheet_name)
        next unless config

        workbook.default_sheet = sheet_name
        next if workbook.last_row.to_i < 2

        header_map = header_map(workbook.row(1), config.headers)
        current_title = nil
        current_description = nil
        current_category = nil

        (2..workbook.last_row).each do |row_index|
          raw_row = workbook.row(row_index)
          next if raw_row.all? { |value| value.to_s.strip.blank? }

          row = build_row(raw_row, header_map)
          current_title = row[:deck_title].presence || current_title
          current_description = row[:deck_description].presence || current_description
          category = category_value(row[:category])
          current_category = category || current_category || Deck.categories[:other]
          total_cards += 1

          validate_row!(sheet_name, row_index, row, current_title, current_category, category, config.card_type)
          next if @errors.any?

          groups[current_title] ||= { description: current_description, category: current_category, cards: [] }
          groups[current_title][:cards] << card_attributes(row, config.card_type)
        end
      end

      @errors << "최대 #{IMPORT_LIMIT}장까지 업로드할 수 있습니다." if total_cards > IMPORT_LIMIT
      groups.each do |title, group|
        next unless Deck.content_size_bytes(title: title, description: group[:description], cards: group[:cards]) > Deck::PERSONAL_DECK_SIZE_LIMIT_BYTES

        @errors << "'#{title}' 덱은 1MB를 초과합니다."
      end
      groups
    end

    def sheet_config(sheet_name)
      HEADER_CONFIGS.find { |key, _| sheet_name.to_s.include?(key) }&.last
    end

    def header_map(header_row, expected_headers)
      normalized = header_row.each_with_index.to_h { |header, index| [ normalize_header(header), index ] }
      expected_headers.transform_values { |header| normalized[normalize_header(header)] }
    end

    def build_row(raw_row, header_map)
      header_map.to_h do |key, index|
        [ key, index.nil? ? nil : raw_row[index].to_s.strip ]
      end
    end

    def validate_row!(sheet_name, row_index, row, deck_title, current_category, category, card_type)
      missing = []
      missing << "덱 제목" if deck_title.blank?
      missing << "분류코드" if current_category.blank?
      missing << "분류코드(1~6)" if row[:category].present? && category.blank?
      missing << "문제" if row[:front].blank?
      missing << "정답" if row[:back].blank?

      if card_type == :multiple_choice
        missing << "오답1" if row[:wrong_1].blank?
        missing << "오답2" if row[:wrong_2].blank?
        missing << "오답3" if row[:wrong_3].blank?
        choices = [ row[:back], row[:wrong_1], row[:wrong_2], row[:wrong_3] ].compact_blank
        missing << "중복 없는 정답/오답" if choices.uniq.size != choices.size
      end

      @errors << "#{sheet_name} #{row_index}행: #{missing.join(', ')} 입력을 확인해 주세요." if missing.any?
    end

    def card_attributes(row, card_type)
      attrs = {
        front: row[:front],
        back: row[:back],
        hint: row[:hint],
        tags: row[:tags],
        card_type: card_type
      }
      attrs[:answer_choices] = [ row[:wrong_1], row[:wrong_2], row[:wrong_3] ] if card_type == :multiple_choice
      attrs
    end

    def save_groups!(groups)
      decks = []
      ActiveRecord::Base.transaction do
        groups.each do |title, group|
          deck = Deck.create!(
            title: title,
            description: group[:description],
            category: group[:category],
            scope: :personal,
            owner: @user
          )
          group[:cards].each_with_index do |attrs, index|
            deck.cards.create!(attrs.merge(position: index + 1))
          end
          decks << deck
        end
      end
      decks
    end

    def normalize_header(value)
      value.to_s.gsub(/\s+/, "")
    end

    def category_value(value)
      return if value.blank?

      Deck.category_filter_value(value)
    end

    def failure(messages)
      Result.new(success?: false, decks: [], cards_count: 0, errors: Array(messages))
    end

    def deck_limit_error
      "사용자 정의 덱은 최대 #{@user.personal_deck_limit}개까지 추가할 수 있습니다. 덱 추가 승인요청 후 다시 시도해 주세요."
    end
  end
end
