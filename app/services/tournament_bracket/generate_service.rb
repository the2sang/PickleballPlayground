module TournamentBracket
  class GenerateService
    Result = Data.define(:success, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call(**args) = new(**args).call

    def initialize(tournament_event:, advancing_team_ids: nil)
      @event = tournament_event
      @advancing_team_ids = Array(advancing_team_ids).reject(&:blank?)
    end

    def call
      advancing_groups = collect_advancing_groups
      advancing = advancing_groups.flatten
      return Result.new(success: false, error: "진출 팀이 없습니다.") if advancing.empty?

      bracket_size = next_power_of_two(advancing.size)
      seeded       = seed_teams(advancing_groups, bracket_size)

      ActiveRecord::Base.transaction do
        Match.where(matchable: @event).destroy_all
        build_bracket(seeded)
        @event.update!(status: :bracket)
      end

      Result.new(success: true, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, error: e.message)
    end

    private

    def collect_advancing_groups
      advances = @event.advances_per_group
      selected_ids = @advancing_team_ids.map(&:to_i).to_set

      @event.tournament_groups.order(:name).map do |group|
        standings = TournamentGroups::StandingsService.call(tournament_group: group).data
        ranked_teams = standings.map { |r| r[:team] }
        @advancing_team_ids.present? ? ranked_teams.select { |team| selected_ids.include?(team.id) } : ranked_teams.first(advances)
      end.reject(&:empty?)
    end

    # Cross-seed group winners against another group's runner-up:
    # 2 groups x top 2 => [A1, B2, B1, A2].
    def seed_teams(groups, bracket_size)
      seeded = cross_seed_top_two(groups)
      seeded += remaining_ranked_teams(groups, seeded)
      seeded = groups.flatten if seeded.empty?
      seeded.first(bracket_size) + Array.new(bracket_size - seeded.size)
    end

    def cross_seed_top_two(groups)
      first_place = groups.map(&:first).compact
      second_place = groups.map { |group| group[1] }.compact
      return [] unless first_place.any? && first_place.size == second_place.size

      first_place.flat_map.with_index do |team, index|
        [ team, second_place[(index + 1) % second_place.size] ]
      end
    end

    def remaining_ranked_teams(groups, seeded)
      seeded_ids = seeded.map(&:id).to_set
      groups.flatten.reject { |team| seeded_ids.include?(team.id) }
    end

    def build_bracket(seeded)
      round     = 1
      match_num = 1

      current_round = seeded.each_slice(2).map do |home_team, away_team|
        is_bye = home_team.nil? || away_team.nil?
        m = Match.create!(
          matchable:    @event,
          home_team:    home_team,
          away_team:    away_team,
          round:        round,
          match_number: match_num,
          status:       is_bye ? :completed : :pending,
          winner:       home_team.nil? ? away_team : (away_team.nil? ? home_team : nil)
        )
        match_num += 1
        m
      end

      while current_round.size > 1
        round += 1
        next_round = current_round.each_slice(2).map do |m1, m2|
          parent = Match.create!(
            matchable:    @event,
            home_team:    nil,
            away_team:    nil,
            round:        round,
            match_number: match_num,
            status:       :pending
          )
          match_num += 1

          m1.update!(next_match: parent)
          m2&.update!(next_match: parent)

          parent.update!(home_team: m1.winner) if m1.winner.present?
          parent.update!(away_team: m2.winner) if m2&.winner.present?

          parent
        end
        current_round = next_round
      end
    end

    def next_power_of_two(n)
      return 1 if n <= 1
      (Math.log2(n).ceil).then { |e| 2**e }
    end
  end
end
