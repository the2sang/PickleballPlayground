module TournamentBracket
  class GenerateService
    Result = Data.define(:success, :error) do
      def success? = success
      def failure? = !success
    end

    def self.call(**args) = new(**args).call

    def initialize(tournament_event:)
      @event = tournament_event
    end

    def call
      advancing = collect_advancing_teams
      return Result.new(success: false, error: "진출 팀이 없습니다.") if advancing.empty?

      bracket_size = next_power_of_two(advancing.size)
      seeded       = seed_teams(advancing, bracket_size)

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

    def collect_advancing_teams
      advances = @event.advances_per_group
      @event.tournament_groups.map do |group|
        standings = TournamentGroups::StandingsService.call(tournament_group: group).data
        standings.first(advances).map { |r| r[:team] }
      end.flatten
    end

    # Cross-seed: group teams by rank tier, reversing odd-rank tiers so teams
    # from the same group never meet in R1 (e.g. 2 groups × 2 advances produces
    # [A1, B1, B2, A2] → Match 1: A1 vs B1, Match 2: B2 vs A2).
    def seed_teams(teams, bracket_size)
      advances = @event.advances_per_group
      groups   = teams.each_slice(advances).to_a

      # transpose → [[rank1_of_each_group], [rank2_of_each_group], ...]
      # reversing odd-rank tiers ensures no same-group pairing in R1
      interleaved = groups.transpose.flat_map.with_index do |rank_teams, i|
        i.odd? ? rank_teams.reverse : rank_teams
      end

      seeded = Array.new(bracket_size)
      interleaved.compact.each_with_index { |t, i| seeded[i] = t }
      seeded
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
