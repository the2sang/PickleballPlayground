module Flashcards
  class PasteImportService
    IMPORT_LIMIT = 500

    ParsedCard = Struct.new(:front, :back, :hint, :tags, :row_index, :warnings, keyword_init: true) do
      def importable? = warnings.empty?
    end

    Result = Struct.new(:success?, :preview_cards, :importable_count, :warnings, :errors, :saved_count, keyword_init: true) do
      def failure? = !success?
    end

    def self.call(**args) = new(**args).call

    def initialize(text:, separator:, deck:, mode: :preview)
      @text      = text.to_s
      @separator = separator.to_s
      @deck      = deck
      @mode      = mode
    end

    def call
      return failure("텍스트가 비어 있습니다.") if @text.strip.empty?
      return failure("구분자를 선택해 주세요.") if @separator.empty?

      lines = @text.lines.map(&:chomp).reject { |l| l.strip.empty? }
      return failure("최대 #{IMPORT_LIMIT}장까지 가져올 수 있습니다.") if lines.size > IMPORT_LIMIT
      return failure("입력할 줄이 없습니다.") if lines.empty?

      parsed = lines.each_with_index.map { |line, i| parse_line(line, i + 1) }

      # 덱 내 중복 front 검출 (DB 쿼리 1회 — N+1 회피)
      fronts = parsed.map(&:front).compact_blank
      existing_fronts = @deck.cards.where(front: fronts).pluck(:front).to_set
      batch_dupes = parsed.map(&:front).compact_blank.tally.select { |_, count| count > 1 }.keys.to_set
      parsed.each do |c|
        next if c.front.blank?
        c.warnings << "덱 내 중복 카드: #{c.front}" if existing_fronts.include?(c.front)
        c.warnings << "배치 내 중복 카드: #{c.front}" if batch_dupes.include?(c.front)
      end

      importable = parsed.count(&:importable?)

      if @mode == :save
        return failure("저장할 수 있는 카드가 없습니다. 경고를 해결해 주세요.") if importable == 0

        save_cards!(parsed.select(&:importable?))
      else
        Result.new(
          success?: true, preview_cards: parsed,
          importable_count: importable, warnings: [], errors: [], saved_count: 0
        )
      end
    end

    private

    def parse_line(line, index)
      parts = line.split(@separator, -1).map { |p| p&.strip }
      front, back, hint, tags = parts[0], parts[1], parts[2], parts[3]
      warnings = []
      warnings << "앞면 또는 뒷면이 비어 있습니다." if front.blank? || back.blank?
      if parts.compact_blank.size > 4
        warnings << "구분자 충돌 — 열 수 초과 (#{parts.compact_blank.size}개 열 감지됨)"
      end
      ParsedCard.new(front: front, back: back, hint: hint, tags: tags, row_index: index, warnings: warnings)
    end

    def save_cards!(cards)
      saved = 0
      ActiveRecord::Base.transaction do
        cards.each do |c|
          @deck.cards.create!(
            front: c.front, back: c.back, hint: c.hint,
            tags: c.tags, card_type: :basic
          )
          saved += 1
        end
      end
      Result.new(
        success?: true, preview_cards: cards, importable_count: cards.size,
        warnings: [], errors: [], saved_count: saved
      )
    rescue ActiveRecord::RecordInvalid => e
      failure("저장 실패 (전체 롤백): #{e.message}")
    end

    def failure(msg)
      Result.new(
        success?: false, preview_cards: [], importable_count: 0,
        warnings: [], errors: [ msg ], saved_count: 0
      )
    end
  end
end
