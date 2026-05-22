require "rails_helper"

RSpec.describe TournamentEvent, type: :model do
  subject { build(:tournament_event) }

  describe "associations" do
    it { is_expected.to belong_to(:tournament) }
    it { is_expected.to have_many(:tournament_teams).dependent(:destroy) }
    it { is_expected.to have_many(:tournament_groups).dependent(:destroy) }
    it { is_expected.to have_many(:matches).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:discipline) }
    it { is_expected.to validate_presence_of(:points_to_win) }
    it { is_expected.to validate_numericality_of(:advances_per_group).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:points_to_win).is_greater_than(0) }
  end

  describe "enums" do
    it do
      is_expected.to define_enum_for(:discipline).with_values(
        mens_singles: 0, mens_doubles: 1,
        womens_singles: 2, womens_doubles: 3, mixed_doubles: 4
      )
    end

    it { is_expected.to define_enum_for(:scoring_format).with_values(single_game: 0, best_of_3: 1) }
    it { is_expected.to define_enum_for(:status).with_values(setup: 0, qualifying: 1, bracket: 2, completed: 3) }
  end

  describe "#singles?" do
    it "returns true for mens_singles" do
      event = build(:tournament_event, discipline: :mens_singles)
      expect(event.singles?).to be true
    end

    it "returns false for doubles" do
      event = build(:tournament_event, discipline: :mens_doubles)
      expect(event.singles?).to be false
    end
  end

  describe "#max_team_size" do
    it "returns 1 for singles" do
      event = build(:tournament_event, discipline: :womens_singles)
      expect(event.max_team_size).to eq(1)
    end

    it "returns 2 for doubles" do
      event = build(:tournament_event, discipline: :mixed_doubles)
      expect(event.max_team_size).to eq(2)
    end
  end
end
