require "test_helper"

class Decks::StudyCardEditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @deck = Deck.create!(title: "My Drill Deck", scope: :personal, owner: @user)
    @card = @deck.cards.create!(
      front: "Kitchen",
      back: "Non-volley zone",
      card_type: :multiple_choice,
      answer_choices: [ "Serve", "Baseline", "Fault" ]
    )
    sign_in_as(@user)
  end

  test "updates question and wrong answer choices but preserves the correct answer" do
    patch deck_study_card_edit_path(@deck, @card),
      params: {
        card: {
          front: "What is the kitchen?",
          back: "Changed correct answer",
          answer_choices: [ "Service box", "Sideline", "Backcourt" ]
        }
      },
      as: :turbo_stream

    assert_response :success
    @card.reload
    assert_equal "What is the kitchen?", @card.front
    assert_equal "Non-volley zone", @card.back
    assert_equal [ "Service box", "Sideline", "Backcourt" ], @card.answer_choices
  end

  test "rejects edits from users without deck update permission" do
    other_user = users(:two)
    sign_in_as(other_user)

    patch deck_study_card_edit_path(@deck, @card),
      params: { card: { front: "Unauthorized edit", answer_choices: [ "A", "B", "C" ] } },
      as: :turbo_stream

    assert_redirected_to root_path
    assert_equal "Kitchen", @card.reload.front
  end
end
