require "test_helper"

class Decks::StudiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @deck = Deck.create!(title: "Rules", scope: :official)
    @easy_card = create_multiple_choice_card("Serve", "A legal start")
    @hard_card = create_multiple_choice_card("Kitchen", "Non-volley zone")
    sign_in_as(@user)
  end

  test "show renders bookmark and difficulty controls for the current multiple choice card" do
    get deck_study_path(@deck)

    assert_response :success
    assert_select ".quiz-card-tools"
    assert_select "button[data-action='click->quiz-session#toggleBookmark']", 1
    assert_select ".quiz-difficulty button[data-action='click->quiz-session#rateDifficulty']", 5
  end

  test "show filters study cards to bookmarked cards" do
    CardBookmark.create!(user: @user, card: @hard_card)

    get deck_study_path(@deck, card_filter: "bookmarked")

    assert_response :success
    assert_select ".quiz-card__text", text: "Kitchen"
    assert_select ".quiz-card__position", text: "1 / 1"
  end

  test "show filters study cards by exact difficulty" do
    UserCardRating.create!(user: @user, card: @easy_card, difficulty: 2)
    UserCardRating.create!(user: @user, card: @hard_card, difficulty: 4)

    get deck_study_path(@deck, difficulty: 4)

    assert_response :success
    assert_select ".quiz-card__text", text: "Kitchen"
    assert_select ".quiz-card__position", text: "1 / 1"
  end

  private

  def create_multiple_choice_card(front, back)
    @deck.cards.create!(
      front: front,
      back: back,
      card_type: :multiple_choice,
      answer_choices: [ "#{front} wrong 1", "#{front} wrong 2", "#{front} wrong 3" ]
    )
  end
end
