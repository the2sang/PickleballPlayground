require "test_helper"

class Decks::BrowsesControllerTest < ActionDispatch::IntegrationTest
  test "show renders styled browse card controls" do
    sign_in_as(users(:one))
    deck = Deck.create!(title: "Rules", scope: :official)
    deck.cards.create!(front: "Kitchen", back: "Non-volley zone")

    get deck_browse_path(deck)

    assert_response :success
    assert_select ".study-page .browse-card"
    assert_select ".browse-card__front[data-browse-target='front']"
    assert_select ".browse-card__back[data-browse-target='back']"
    assert_select ".browse-actions .browse-actions__button", text: /답 보기/
    assert_select ".browse-nav .browse-nav__button", text: /이전/
    assert_select ".browse-shuffle[data-browse-target='shuffleButton']", text: /셔플/
  end
end
