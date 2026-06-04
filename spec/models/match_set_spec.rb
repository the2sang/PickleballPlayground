require "rails_helper"

RSpec.describe MatchSet, type: :model do
  subject { build(:match_set) }

  describe "associations" do
    it { is_expected.to belong_to(:match) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:set_number) }
    it { is_expected.to validate_numericality_of(:home_score).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:away_score).is_greater_than_or_equal_to(0) }
  end
end
