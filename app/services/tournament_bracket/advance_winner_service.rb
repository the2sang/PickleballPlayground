module TournamentBracket
  class AdvanceWinnerService
    Result = Data.define(:success, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call(**args) = new(**args).call

    def initialize(match:)
      @match = match
    end

    def call
      return Result.new(success: false, error: "승자가 결정되지 않았습니다.") if @match.winner.nil?

      ActiveRecord::Base.transaction do
        @match.update!(status: :locked)

        if @match.next_match.present?
          assign_to_next_match
        else
          @match.matchable.update!(status: :completed)
        end
      end

      Result.new(success: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, error: e.message)
    end

    private

    def assign_to_next_match
      next_match = @match.next_match.lock!
      if next_match.home_team_id.nil?
        next_match.update!(home_team: @match.winner)
      else
        next_match.update!(away_team: @match.winner)
      end
    end
  end
end
