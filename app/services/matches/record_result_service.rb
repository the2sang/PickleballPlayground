module Matches
  class RecordResultService
    Result = Data.define(:success, :warning, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call(**args) = new(**args).call

    def initialize(match:, sets:)
      @match = match
      @sets  = sets
    end

    def call
      validation_error = validate_scores
      return Result.new(success: false, warning: nil, error: validation_error) if validation_error

      warning = next_round_warning

      ActiveRecord::Base.transaction do
        @match.match_sets.destroy_all
        @sets.each_with_index do |set_data, i|
          @match.match_sets.create!(
            set_number: i + 1,
            home_score: set_data[:home_score],
            away_score: set_data[:away_score]
          )
        end

        winner = determine_winner
        @match.update!(winner: winner, status: :completed)
      end

      Result.new(success: true, warning: warning, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, warning: nil, error: e.message)
    end

    private

    def validate_scores
      points_to_win = @match.tournament_event.points_to_win

      @sets.each do |set|
        h = set[:home_score].to_i
        a = set[:away_score].to_i
        max = [ h, a ].max
        min = [ h, a ].min
        diff = max - min

        # 세트 유효 조건: max >= points_to_win AND 2점 차 이상
        unless max >= points_to_win && diff >= 2
          return "#{h}:#{a} — 2점 차이 이상이어야 세트가 종료됩니다 (win-by-2 규칙)."
        end
      end

      nil
    end

    def determine_winner
      home_sets = 0
      away_sets = 0
      @sets.each do |set|
        if set[:home_score].to_i > set[:away_score].to_i
          home_sets += 1
        else
          away_sets += 1
        end
      end
      home_sets > away_sets ? @match.home_team : @match.away_team
    end

    def next_round_warning
      return nil unless @match.next_round_started?

      "다음 라운드 경기가 이미 진행 중입니다. 결과를 수정하면 대진표가 변경될 수 있습니다."
    end
  end
end
