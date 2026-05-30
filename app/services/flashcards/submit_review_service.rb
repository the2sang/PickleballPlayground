# frozen_string_literal: true

module Flashcards
  # ApplicationService 상속 금지 — D-21 (PORO only)
  class SubmitReviewService
    Result = Struct.new(:success?, :card_review, :errors, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(user:, card_id:, rating:)
      @user    = user
      @card_id = card_id
      @rating  = rating
    end

    def call
      card_review = CardReview.find_or_initialize_by(user: @user, card_id: @card_id)

      # Pitfall 7 방어 (필수): nil 값이 SM2Service에 전달되지 않도록 기본값 보호.
      # find_or_initialize_by로 얻은 신규 in-memory 레코드는 DB 컬럼 기본값이 없으면 nil.
      current_state = {
        ease:          card_review.ease          || 2.5,
        interval_days: card_review.interval_days || 0,
        repetitions:   card_review.repetitions   || 0
      }

      sm2_result = Flashcards::Sm2Service.call(**current_state, rating: @rating)

      card_review.update!(
        ease:             sm2_result.ease,
        interval_days:    sm2_result.interval_days,
        repetitions:      sm2_result.repetitions,
        next_review_at:   sm2_result.next_review_at,
        last_reviewed_at: Time.current,
        last_rating:      @rating
      )

      Result.new(success?: true, card_review: card_review, errors: [])

    rescue ActiveRecord::RecordNotUnique
      # Pitfall 9 방어: bare retry 절대 금지 (무한루프 위험)
      # find_or_initialize_by 이후 동시 요청이 unique 제약 위반 시 복구 경로
      begin
        card_review = CardReview.find_by!(user: @user, card_id: @card_id)
        card_review.update!(
          ease:             sm2_result.ease,
          interval_days:    sm2_result.interval_days,
          repetitions:      sm2_result.repetitions,
          next_review_at:   sm2_result.next_review_at,
          last_reviewed_at: Time.current,
          last_rating:      @rating
        )
        Result.new(success?: true, card_review: card_review, errors: [])
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success?: false, card_review: nil, errors: e.record.errors.full_messages)
      end

    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, card_review: nil, errors: e.record.errors.full_messages)
    end

    private

    attr_reader :user, :card_id, :rating
  end
end
