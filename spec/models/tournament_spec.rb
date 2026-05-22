require "rails_helper"

RSpec.describe Tournament, type: :model do
  subject { build(:tournament) }

  describe "associations" do
    it { is_expected.to belong_to(:club) }
    it { is_expected.to have_many(:tournament_events).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:club) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, in_progress: 1, completed: 2) }
  end
end
