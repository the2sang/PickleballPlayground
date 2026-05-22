require "rails_helper"

RSpec.describe Match, type: :model do
  subject { build(:match) }

  describe "associations" do
    it { is_expected.to belong_to(:matchable) }
    it { is_expected.to belong_to(:home_team).class_name("TournamentTeam").optional }
    it { is_expected.to belong_to(:away_team).class_name("TournamentTeam").optional }
    it { is_expected.to belong_to(:winner).class_name("TournamentTeam").optional }
    it { is_expected.to belong_to(:next_match).class_name("Match").optional }
    it { is_expected.to have_many(:match_sets).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, locked: 3) }
  end

  describe "#bye?" do
    it "returns true when one team is nil" do
      match = build(:match, away_team: nil)
      expect(match.bye?).to be true
    end

    it "returns false when both teams present" do
      expect(subject.bye?).to be false
    end
  end

  describe "#next_round_started?" do
    it "returns false when next_match is nil" do
      match = build(:match, next_match: nil)
      expect(match.next_round_started?).to be false
    end

    it "returns true when next_match is in_progress or completed" do
      next_match = build(:match, status: :in_progress)
      match = build(:match, next_match: next_match)
      expect(match.next_round_started?).to be true
    end
  end
end
