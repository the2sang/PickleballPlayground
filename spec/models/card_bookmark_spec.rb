require "rails_helper"

RSpec.describe CardBookmark, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:card) }
  end

  describe "validations" do
    subject(:bookmark) { build(:card_bookmark) }

    it { is_expected.to validate_uniqueness_of(:card_id).scoped_to(:user_id) }
  end
end
