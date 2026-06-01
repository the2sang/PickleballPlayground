require "test_helper"

class Decks::FlipsControllerTest < ActionDispatch::IntegrationTest
  test "show includes a pause control for the answer-side auto flip" do
    deck = Deck.create!(title: "Flip pause deck", scope: :official)
    deck.cards.create!(front: "What is NVZ?", back: "Kitchen", position: 1)

    get deck_flip_path(deck)

    assert_response :success
    assert_select "[data-flip-card-target='pauseBtn'][data-action='click->flip-card#togglePause']", 1
    assert_select "[data-flip-card-target='pauseIcon'][icon='lucide:pause']", 1
  end
end
