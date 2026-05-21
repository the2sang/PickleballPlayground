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

    # Cross-seed: A조1위 vs B조2위, B조1위 vs A조2위 등 같은 조가 1라운드에 안 만나도록
    def seed_teams(teams, bracket_size)
      seeded = Array.new(bracket_size)          # nil = bye
      top    = teams.each_slice(2).map(&:first) # 각 조 1위
      second = teams.each_slice(2).map(&:last)  # 각 조 2위 (없으면 nil)
      second.compact!

      positions = (0...bracket_size).to_a
      top.each_with_index    { |t, i| seeded[positions[i * 2]]     = t }
      second.each_with_index { |t, i| seeded[positions[i * 2 + 1]] = t }
      seeded
    end

    def build_bracket(seeded)
      round       = 1
      match_num   = 1
      pairs       = seeded.each_slice(2).to_a
      next_slots  = []

      while pairs.size > 1
        current_round_matches = pairs.map do |home_team, away_team|
          Match.create!(
            matchable:    @event,
            home_team:    home_team,
            away_team:    away_team,
            round:        round,
            match_number: match_num,
            status:       home_team.nil? || away_team.nil? ? :completed : :pending,
            winner:       home_team.nil? ? away_team : (away_team.nil? ? home_team : nil)
          ).tap { match_num += 1 }
        end
        next_slots << current_round_matches
        pairs = current_round_matches.each_slice(2).map { |a, b| [ a, b ] }
        round += 1
      end

      # 결승
      semi_pairs = next_slots.last
      final = Match.create!(
        matchable:    @event,
        home_team:    nil,
        away_team:    nil,
        round:        round,
        match_number: match_num,
        status:       :pending
      )

      semi_pairs.each { |m| m.update!(next_match: final) }
    end

    def next_power_of_two(n)
      return 1 if n <= 1
      (Math.log2(n).ceil).then { |e| 2**e }
    end
  end
end
