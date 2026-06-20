require "rails_helper"

RSpec.describe OpenSessions::MatchPlanBuilder do
  describe "#call" do
    it "requires at least five confirmed participants" do
      session = create(:game_session, :open_game)
      create_list(:participation, 4, :profile_complete_user, game_session: session, status: :confirmed)

      plan = described_class.new(game_session: session, rounds: 3).call

      expect(plan).not_to be_success
      expect(plan.error).to eq("매칭 생성은 확정 참가자 5명 이상부터 가능합니다.")
    end

    it "keeps the selected fixed pair from the configured round" do
      session = create(:game_session, :open_game)
      participations = create_list(:participation, 8, :profile_complete_user,
                                   game_session: session, status: :confirmed)
      host = participations.first.user
      partner = participations.second.user

      plan = described_class.new(
        game_session: session,
        rounds: 4,
        fixed_user_id: host.id,
        fixed_partner_user_id: partner.id,
        fixed_partner_starts_round: 2
      ).call

      expect(plan).to be_success
      fixed_rounds = plan.rounds.select { |round| round.number >= 2 }
      expect(fixed_rounds).to all(have_fixed_pair(host.id, partner.id))
    end
  end

  def have_fixed_pair(first_user_id, second_user_id)
    satisfy("include both users on the same team") do |round|
      round.games.any? do |game|
        [ game.home, game.away ].any? do |team|
          team.players.map(&:id).sort == [ first_user_id, second_user_id ].sort
        end
      end
    end
  end
end
