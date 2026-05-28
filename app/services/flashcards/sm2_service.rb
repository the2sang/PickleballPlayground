module Flashcards
  # Pure-Ruby SM-2 spaced repetition algorithm.
  # No ActiveRecord, no Rails dependencies beyond Time.current.
  #
  # Public domain spec: Piotr Woźniak, SuperMemo (1987).
  # See .planning/phases/01-foundations/01-RESEARCH.md §1 for derivation.
  #
  # Caller (Phase 3 SubmitReviewService) is responsible for persisting
  # last_rating / last_reviewed_at — this service only computes the next
  # (ease, interval_days, repetitions, next_review_at) tuple.
  class Sm2Service
    EASE_FLOOR    = 1.3
    INITIAL_EASE  = 2.5
    QUALITY_MAP   = { 1 => 1, 2 => 3, 3 => 4, 4 => 5 }.freeze   # LOCKED (user decision)
    VALID_RATINGS = [ 1, 2, 3, 4 ].freeze

    Result = Struct.new(:ease, :interval_days, :repetitions, :next_review_at, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(ease:, interval_days:, repetitions:, rating:, now: Time.current)
      unless rating.is_a?(Integer) && VALID_RATINGS.include?(rating)
        raise ArgumentError, "rating must be one of #{VALID_RATINGS} (got #{rating.inspect})"
      end

      @ease        = ease.to_f
      @interval    = interval_days.to_i
      @repetitions = repetitions.to_i
      @q           = QUALITY_MAP.fetch(rating)
      @now         = now
    end

    def call
      new_ease = [ @ease + (0.1 - (5 - @q) * (0.08 + (5 - @q) * 0.02)), EASE_FLOOR ].max

      if @q < 3                                # lapse
        new_reps     = 0
        new_interval = 1
      else
        new_reps     = @repetitions + 1
        new_interval = case @repetitions       # NB: pre-increment value
        when 0 then 1
        when 1 then 6
        else (@interval * new_ease).round
        end
      end

      Result.new(
        ease:           new_ease.round(2),
        interval_days:  new_interval,
        repetitions:    new_reps,
        next_review_at: @now + new_interval.days
      )
    end
  end
end
