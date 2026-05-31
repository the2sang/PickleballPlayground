# frozen_string_literal: true

module Flashcards
  class StreakQuery
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      today_kst = Time.current.in_time_zone("Asia/Seoul").to_date

      reviewed_dates = Set.new(
        CardReview.where(user: @user)
                  .pluck(Arel.sql("DATE(DATETIME(updated_at, '+9 hours'))"))
                  .map(&:to_date)
      )

      return 0 unless reviewed_dates.include?(today_kst) || reviewed_dates.include?(today_kst - 1.day)

      check_date = reviewed_dates.include?(today_kst) ? today_kst : today_kst - 1.day
      streak = 0

      while reviewed_dates.include?(check_date)
        streak += 1
        check_date -= 1.day
      end

      streak
    end
  end
end
