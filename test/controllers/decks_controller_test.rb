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
      assert_select "a.deck-hub-tabs__trigger", text: /마이 덱/
      assert_select "a.deck-hub-tabs__trigger", text: /북마크 덱/
    end
    assert_select "[role='tabpanel'] .deck-collection__title", text: "공식 덱"
  end

  test "index prompts login when unauthenticated visitor selects personal tab" do
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path(deck_tab: "personal")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger[aria-selected='true']", text: /마이 덱/
    assert_select ".cl-empty__text", text: "마이 덱은 로그인 후 사용할 수 있습니다."
    assert_select "a[href='#{new_session_path}']", text: /로그인하고 시작하기/
  end

  test "index prompts login when unauthenticated visitor selects bookmarked tab" do
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path(deck_tab: "bookmarked")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger[aria-selected='true']", text: /북마크 덱/
    assert_select ".cl-empty__text", text: "북마크 덱은 로그인 후 사용할 수 있습니다."
    assert_select "a[href='#{new_session_path}']", text: /로그인하고 확인하기/
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
      assert_select "a.deck-hub-tabs__trigger", text: /마이 덱/
      assert_select "a.deck-hub-tabs__trigger iconify-icon[icon='lucide:folder-user']", 1
      assert_select "a.deck-hub-tabs__trigger", text: /북마크 덱/
      assert_select "a.deck-hub-tabs__trigger iconify-icon[icon='lucide:bookmark-check']", 1
    end
    assert_select "[role='tabpanel'] .deck-collection__title", text: "공식 덱"
    assert_select ".deck-card__title", text: "Official Rules"
    assert_select ".deck-card__title", text: "My Drill Notes", count: 0
  end

  test "index shows bookmarked official and personal decks in carousel when selected" do
    sign_in_as(users(:one))
    official_bookmarked = Deck.create!(title: "Bookmarked Official", scope: :official)
    official_plain = Deck.create!(title: "Plain Official", scope: :official)
    personal_bookmarked = Deck.create!(title: "Bookmarked Personal", scope: :personal, owner: users(:one))
    personal_plain = Deck.create!(title: "Plain Personal", scope: :personal, owner: users(:one))
    club_deck = Deck.create!(title: "Bookmarked Club", scope: :club, owner: clubs(:approved_club))
    DeckBookmark.create!(user: users(:one), deck: official_bookmarked)
    DeckBookmark.create!(user: users(:one), deck: personal_bookmarked)
    DeckBookmark.create!(user: users(:one), deck: club_deck)

    get decks_path(deck_tab: "bookmarked")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger[aria-selected='true']", text: /북마크 덱/
    assert_select "[role='tabpanel'] .deck-carousel" do
      assert_select ".deck-carousel__title", text: "북마크 덱"
      assert_select ".deck-carousel__nav--prev", 1
      assert_select ".deck-carousel__nav--next", 1
      assert_select ".deck-card__title", text: "Bookmarked Official"
      assert_select ".deck-card__title", text: "Bookmarked Personal"
      assert_select ".deck-card__title", text: "Plain Official", count: 0
      assert_select ".deck-card__title", text: "Plain Personal", count: 0
      assert_select ".deck-card__title", text: "Bookmarked Club", count: 0
    end

    assert_not_nil official_plain
    assert_not_nil personal_plain
  end

  test "index shows personal deck tab content when selected" do
    sign_in_as(users(:one))
    Deck.create!(title: "Official Rules", scope: :official)
    Deck.create!(title: "My Drill Notes", scope: :personal, owner: users(:one))

    get decks_path(deck_tab: "personal")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger[aria-selected='true']", text: /마이 덱/
    assert_select "[role='tabpanel'] .deck-collection__title", text: "마이 덱"
    assert_select "[role='tabpanel'] .deck-collection__title iconify-icon[icon='lucide:folder-user']", 1
    assert_select ".deck-card__title", text: "My Drill Notes"
    assert_select ".deck-card__title", text: "Official Rules", count: 0
  end

  test "index shows personal tab empty state for users without personal decks" do
    sign_in_as(users(:one))
    Deck.create!(title: "Official Rules", scope: :official)

    get decks_path(deck_tab: "personal")

    assert_response :success
    assert_select ".deck-hub-tabs__trigger", text: /마이 덱/
    assert_select ".cl-empty__text", text: "아직 만든 마이 덱이 없습니다."
  end

  test "show includes bookmarked and exact difficulty study links when available" do
    sign_in_as(users(:one))
    deck = Deck.create!(title: "Official Rules", scope: :official)
    card = deck.cards.create!(
      front: "Kitchen",
      back: "Non-volley zone",
      card_type: :multiple_choice,
      answer_choices: [ "Serve", "Baseline", "Fault" ]
    )
    CardBookmark.create!(user: users(:one), card: card)
    UserCardRating.create!(user: users(:one), card: card, difficulty: 4)

    get deck_path(deck)

    assert_response :success
    assert_select "a[href='#{deck_study_path(deck, card_filter: "bookmarked")}']", text: "북마크한 문제만"
    assert_select "a[href='#{deck_study_path(deck, difficulty: 4)}']", text: "난이도 4점"
  end
end
