require "test_helper"

class CardBookmarkTest < ActiveSupport::TestCase
  test "requires one bookmark per user and card" do
    user = users(:one)
    deck = Deck.create!(title: "Rules", scope: :official)
    card = deck.cards.create!(
      front: "Kitchen",
      back: "Non-volley zone",
      card_type: :multiple_choice,
      answer_choices: [ "Serve", "Baseline", "Fault" ]
    )

    CardBookmark.create!(user: user, card: card)
    duplicate = CardBookmark.new(user: user, card: card)

    assert_not duplicate.valid?
    assert duplicate.errors[:card_id].present?
  end
end
