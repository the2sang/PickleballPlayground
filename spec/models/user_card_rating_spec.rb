require "rails_helper"

RSpec.describe UserCardRating, type: :model do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:card) }
  end

  describe "validations" do
    subject { UserCardRating.new(user: user, card: card, difficulty: 3) }

    it { is_expected.to validate_uniqueness_of(:card_id).scoped_to(:user_id) }
    it { is_expected.to validate_numericality_of(:difficulty).only_integer
                                                              .is_greater_than_or_equal_to(1)
                                                              .is_less_than_or_equal_to(5) }
    it { is_expected.to validate_presence_of(:difficulty) }
  end
end
