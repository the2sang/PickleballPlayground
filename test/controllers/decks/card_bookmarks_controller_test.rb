require "test_helper"

class Decks::CardBookmarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @deck = Deck.create!(title: "Rules", scope: :official)
    @card = @deck.cards.create!(
      front: "Kitchen",
      back: "Non-volley zone",
      card_type: :multiple_choice,
      answer_choices: [ "Serve", "Baseline", "Fault" ]
    )
    sign_in_as(@user)
  end

  test "creates a card bookmark for current user" do
    assert_difference "CardBookmark.count", 1 do
      post deck_card_bookmarks_path(@deck), params: { card_id: @card.id }
    end

    assert_response :success
    assert CardBookmark.exists?(user: @user, card: @card)
  end

  test "destroys a card bookmark for current user" do
    CardBookmark.create!(user: @user, card: @card)

    assert_difference "CardBookmark.count", -1 do
      delete deck_card_bookmark_path(@deck, @card)
    end

    assert_response :success
  end
end
