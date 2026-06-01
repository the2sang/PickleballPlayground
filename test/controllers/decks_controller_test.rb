require "test_helper"

class DecksControllerTest < ActionDispatch::IntegrationTest
  test "index shows deck community open chat link when configured" do
    Deck.create!(title: "Official Rules", scope: :official)
    SiteSetting.current.update!(
      deck_community_open_chat_url: "https://open.kakao.com/o/pickleball",
      updated_by: users(:admin)
    )

    get decks_path

    assert_response :success
    assert_select "a[href='https://open.kakao.com/o/pickleball'].deck-community-link", 1
    assert_select "img[src*='kakao']", 1
  end

  test "index replaces paste import call to action with deck community link for empty personal deck users" do
    sign_in_as(users(:one))
    Deck.create!(title: "Official Rules", scope: :official)
    SiteSetting.current.update!(
      deck_community_open_chat_url: "https://open.kakao.com/o/pickleball",
      updated_by: users(:admin)
    )

    get decks_path

    assert_response :success
    assert_select "a", text: "붙여넣기 가져오기", count: 0
    assert_select "a[href='https://open.kakao.com/o/pickleball'].deck-community-link", 1
  end

  test "index omits deck community open chat link when not configured" do
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path

    assert_response :success
    assert_select ".deck-community-link", 0
  end
end
