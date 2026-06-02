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

  test "index shows deck hub tabs for unauthenticated visitors" do
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path

    assert_response :success
    assert_select ".deck-hub-tabs[role='tablist']" do
      assert_select "a.deck-hub-tabs__trigger", text: /공식 덱/
      assert_select "a.deck-hub-tabs__trigger", text: /내 덱/
    end
    assert_select "[role='tabpanel'] .deck-collection__title", text: "공식 덱"
  end

  test "index prompts login when unauthenticated visitor selects personal tab" do
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path(deck_tab: "personal")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger[aria-selected='true']", text: /내 덱/
    assert_select ".cl-empty__text", text: "내 덱은 로그인 후 사용할 수 있습니다."
    assert_select "a[href='#{new_session_path}']", text: /로그인하고 시작하기/
  end

  test "index shows official and personal icon tabs for authenticated deck hub" do
    sign_in_as(users(:one))
    Deck.create!(title: "Official Rules", scope: :official)
    Deck.create!(title: "My Drill Notes", scope: :personal, owner: users(:one))

    get decks_path

    assert_response :success
    assert_select ".deck-hub-tabs[role='tablist']" do
      assert_select "a.deck-hub-tabs__trigger[aria-selected='true']", text: /공식 덱/
      assert_select "a.deck-hub-tabs__trigger iconify-icon[icon='lucide:badge-check']", 1
      assert_select "a.deck-hub-tabs__trigger", text: /내 덱/
      assert_select "a.deck-hub-tabs__trigger iconify-icon[icon='lucide:folder-user']", 1
    end
    assert_select "[role='tabpanel'] .deck-collection__title", text: "공식 덱"
    assert_select ".deck-card__title", text: "Official Rules"
    assert_select ".deck-card__title", text: "My Drill Notes", count: 0
  end

  test "index shows personal deck tab content when selected" do
    sign_in_as(users(:one))
    Deck.create!(title: "Official Rules", scope: :official)
    Deck.create!(title: "My Drill Notes", scope: :personal, owner: users(:one))

    get decks_path(deck_tab: "personal")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger[aria-selected='true']", text: /내 덱/
    assert_select "[role='tabpanel'] .deck-collection__title", text: "내 덱"
    assert_select ".deck-card__title", text: "My Drill Notes"
    assert_select ".deck-card__title", text: "Official Rules", count: 0
  end

  test "index shows personal tab empty state for users without personal decks" do
    sign_in_as(users(:one))
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path(deck_tab: "personal")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger", text: /내 덱/
    assert_select ".cl-empty__text", text: "아직 만든 내 덱이 없습니다."
  end
end
