require "rails_helper"

RSpec.describe DeckBookmark, type: :model do
  subject(:bookmark) { build(:deck_bookmark) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:deck) }

  it "사용자별 같은 덱은 한 번만 북마크할 수 있다" do
    user = create(:user)
    deck = create(:deck, :official)
    create(:deck_bookmark, user: user, deck: deck)

    duplicate = build(:deck_bookmark, user: user, deck: deck)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:deck_id]).to be_present
  end
end
