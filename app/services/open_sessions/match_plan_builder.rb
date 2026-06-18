module OpenSessions
  class MatchPlanBuilder
    MIN_PLAYERS = 5
    MAX_ROUNDS = 10

    Player = Data.define(:id, :name)
    Team = Data.define(:players)
    Game = Data.define(:court_label, :home, :away)
    Round = Data.define(:number, :games, :waiting_players, :manual)
    Plan = Data.define(:success, :players, :rounds, :mode, :round_count, :fixed_pair, :error) do
      def success? = success
      def manual? = mode == "manual"
      def automatic? = mode == "automatic"
    end

    def initialize(game_session:, mode: "automatic", rounds: 4,
                   fixed_user_id: nil, fixed_partner_user_id: nil,
                   fixed_partner_starts_round: 1)
      @game_session = game_session
      @mode = mode == "manual" ? "manual" : "automatic"
      @round_count = (rounds.presence || 4).to_i.clamp(1, MAX_ROUNDS)
      @fixed_user_id = fixed_user_id.to_i if fixed_user_id.present?
      @fixed_partner_user_id = fixed_partner_user_id.to_i if fixed_partner_user_id.present?
      @fixed_partner_starts_round = fixed_partner_starts_round.to_i.clamp(1, @round_count)
    end

    def call
      return failure("매칭 생성은 확정 참가자 5명 이상부터 가능합니다.") if players.size < MIN_PLAYERS

      Plan.new(
        success: true,
        players: players,
        rounds: build_rounds,
        mode: mode,
        round_count: round_count,
        fixed_pair: fixed_pair,
        error: nil
      )
    end

    private

    attr_reader :game_session, :mode, :round_count, :fixed_user_id,
                :fixed_partner_user_id, :fixed_partner_starts_round

    def players
      @players ||= game_session.participations.confirmed.includes(:user).order(:created_at).map do |participation|
        Player.new(id: participation.user_id, name: participation.display_name)
      end
    end

    def build_rounds
      (1..round_count).map do |number|
        mode == "manual" ? manual_round(number) : automatic_round(number)
      end
    end

    def manual_round(number)
      games = Array.new(game_count) do |index|
        Game.new(court_label: "게임 #{index + 1}", home: Team.new(players: []), away: Team.new(players: []))
      end
      Round.new(number: number, games: games, waiting_players: players, manual: true)
    end

    def automatic_round(number)
      pool = shuffled_players(number)
      pool = apply_fixed_pair(pool) if fixed_pair_active?(number)

      games = []
      while pool.size >= 4
        games << Game.new(
          court_label: "게임 #{games.size + 1}",
          home: Team.new(players: pool.shift(2)),
          away: Team.new(players: pool.shift(2))
        )
      end

      Round.new(number: number, games: games, waiting_players: pool, manual: false)
    end

    def shuffled_players(round_number)
      players.shuffle(random: Random.new(seed_for(round_number)))
    end

    def seed_for(round_number)
      game_session.id.to_i * 10_000 + round_number * 137 + players.size
    end

    def apply_fixed_pair(pool)
      fixed_ids = [ fixed_user_id, fixed_partner_user_id ]
      fixed_players = fixed_ids.filter_map { |id| players.find { |player| player.id == id } }
      return pool unless fixed_players.size == 2

      fixed_players + pool.reject { |player| fixed_ids.include?(player.id) }
    end

    def fixed_pair_active?(round_number)
      fixed_pair.present? && round_number >= fixed_partner_starts_round
    end

    def fixed_pair
      return unless fixed_user_id.present? && fixed_partner_user_id.present?
      return if fixed_user_id == fixed_partner_user_id
      return unless players.any? { |player| player.id == fixed_user_id }
      return unless players.any? { |player| player.id == fixed_partner_user_id }

      {
        user_id: fixed_user_id,
        partner_user_id: fixed_partner_user_id,
        starts_round: fixed_partner_starts_round
      }
    end

    def game_count
      [ players.size / 4, 1 ].max
    end

    def failure(message)
      Plan.new(
        success: false,
        players: players,
        rounds: [],
        mode: mode,
        round_count: round_count,
        fixed_pair: nil,
        error: message
      )
    end
  end
end
