module Flashcards
  class DeckSessionStatsQuery
    Result = Struct.new(:session_count, :last_score_pct, keyword_init: true)

    def initialize(user:, deck_ids:)
      @user     = user
      @deck_ids = Array(deck_ids)
    end

    def call
      return {} if @deck_ids.empty?

      counts = StudySession.completed
                           .where(user: @user, deck_id: @deck_ids)
                           .group(:deck_id)
                           .count

      last_ids = StudySession.completed
                             .where(user: @user, deck_id: @deck_ids)
                             .group(:deck_id)
                             .maximum(:id)

      last_sessions = last_ids.any? ?
        StudySession.where(id: last_ids.values).index_by(&:deck_id) : {}

      @deck_ids.each_with_object({}) do |deck_id, hash|
        last = last_sessions[deck_id]
        hash[deck_id] = Result.new(
          session_count:  counts[deck_id] || 0,
          last_score_pct: last&.score_pct
        )
      end
    end
  end
end
