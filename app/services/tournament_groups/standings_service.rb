module TournamentGroups
  class StandingsService
    Result = Data.define(:success, :data, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call(**args) = new(**args).call

    def initialize(tournament_group:)
      @group = tournament_group
    end

    def call
      rows = build_rows
      sorted = rows.sort_by { |r| [ -r[:win_pct], -r[:point_diff], -r[:total_points] ] }
      sorted.each_with_index { |r, i| r[:rank] = i + 1 }
      Result.new(success: true, data: sorted, error: nil)
    end

    private

    def build_rows
      teams = @group.teams.to_a
      completed = @group.matches.where(status: :completed).includes(:match_sets)

      teams.map do |team|
        team_matches = completed.select { |m| m.home_team_id == team.id || m.away_team_id == team.id }

        wins   = team_matches.count { |m| m.winner_id == team.id }
        losses = team_matches.count - wins

        total_for     = 0
        total_against = 0
        team_matches.each do |m|
          m.match_sets.each do |s|
            if m.home_team_id == team.id
              total_for     += s.home_score
              total_against += s.away_score
            else
              total_for     += s.away_score
              total_against += s.home_score
            end
          end
        end

        played   = wins + losses
        win_pct  = played.zero? ? 0.0 : wins.to_f / played

        {
          team: team,
          wins: wins,
          losses: losses,
          win_pct: win_pct,
          point_diff: total_for - total_against,
          total_points: total_for,
          rank: nil
        }
      end
    end
  end
end
