module TournamentGroups
  class AutoAssignService
    Result = Data.define(:success, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call(**args) = new(**args).call

    def initialize(tournament_event:, group_count:)
      @event       = tournament_event
      @group_count = group_count
    end

    def call
      teams = @event.tournament_teams.to_a
      return Result.new(success: false, error: "등록된 팀이 없습니다.") if teams.empty?
      return Result.new(success: false, error: "조 수는 1 이상이어야 합니다.") if @group_count < 1

      ActiveRecord::Base.transaction do
        @event.tournament_groups.destroy_all

        groups = @group_count.times.map do |i|
          @event.tournament_groups.create!(name: "#{('A'.ord + i).chr}조")
        end

        teams.shuffle.each_with_index do |team, idx|
          groups[idx % @group_count].tournament_group_teams.create!(tournament_team: team)
        end

        groups.each { |g| generate_round_robin_matches(g) }

        @event.update!(status: :qualifying)
      end

      Result.new(success: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, error: e.message)
    end

    private

    def generate_round_robin_matches(group)
      teams = group.teams.to_a
      match_number = group.matches.count
      teams.combination(2).each_with_index do |(home, away), idx|
        group.matches.create!(
          home_team: home,
          away_team: away,
          round: 0,
          match_number: match_number + idx + 1,
          status: :pending
        )
      end
    end
  end
end
