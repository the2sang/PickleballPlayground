class DecksController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_deck, only: %i[show edit update destroy]
  before_action :authorize_deck!, only: %i[edit update destroy]

  def index
    @site_setting = SiteSetting.current
    @selected_category = Deck.category_filter_value(params[:category])
    @selected_deck_tab = deck_tab_value(params[:deck_tab])
    @category_options = Deck.category_options(include_all: true)
    @bookmarked_deck_ids = authenticated? ? Current.user.deck_bookmarks.pluck(:deck_id) : []
    @official_decks = filter_by_category(Deck.where(scope: :official))
                      .includes(:cards)
                      .then { |scope| order_for_index(scope, :created_at) }
    @bookmarked_decks = authenticated? ? bookmarked_decks_for_index : []

    if authenticated?
      personal_scope = Deck.where(scope: :personal, owner: Current.user)
      @has_personal_decks = personal_scope.exists?
      @personal_decks = personal_scope
                            .then { |scope| filter_by_category(scope) }
                            .includes(:cards)
                            .then { |scope| order_for_index(scope, updated_at: :desc) }
      approved_club_ids = Current.user.club_memberships.approved.pluck(:club_id)
      @show_club_section = approved_club_ids.any?
      @club_decks = @show_club_section ?
        filter_by_category(Deck.where(scope: :club, owner_type: "Club", owner_id: approved_club_ids))
            .includes(:cards).then { |scope| order_for_index(scope, updated_at: :desc) } : []

      all_deck_ids = (@official_decks + @personal_decks + @club_decks + @bookmarked_decks).map(&:id)
      @deck_session_stats = Flashcards::DeckSessionStatsQuery.new(
        user: Current.user, deck_ids: all_deck_ids
      ).call

      @streak         = Flashcards::StreakQuery.call(user: Current.user)
      @today_progress = Flashcards::TodayProgressQuery.call(user: Current.user)
      @due_forecast   = Flashcards::DueForecastQuery.call(user: Current.user)
      set_personal_deck_limit_state
    else
      @personal_decks    = []
      @bookmarked_decks  = []
      @club_decks        = []
      @has_personal_decks = false
      @show_club_section = false
      @deck_session_stats = {}
      @streak         = 0
      @today_progress = { reviewed_today: 0, due_remaining: 0 }
      @due_forecast   = []
      @personal_deck_count = 0
      @personal_deck_limit = Deck::PERSONAL_DECK_LIMIT
      @pending_deck_addition_request = nil
    end
  end

  def show
    authorize @deck
    @cards       = @deck.cards.order(:position, :id)
    @rated_count = authenticated? ?
      UserCardRating.where(user: Current.user, card: @cards).count : 0
    @bookmarked_count = authenticated? ?
      CardBookmark.where(user: Current.user, card: @cards).count : 0
  end

  def new
    @deck = Deck.new(scope: :personal, owner: Current.user)
    set_personal_deck_limit_state
    authorize @deck
  end

  def create
    @deck = Deck.new(deck_params.merge(resolved_scope_and_owner))
    authorize @deck
    if @deck.save
      redirect_to @deck, notice: "덱이 생성되었습니다."
    else
      set_personal_deck_limit_state
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @deck.update(deck_params)
      redirect_to @deck, notice: "덱이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deck.destroy!
    Flashcards::DueCountCacheService.invalidate(Current.user)
    redirect_to decks_path, notice: "덱이 삭제되었습니다."
  end

  private

  def set_deck
    @deck = Deck.find(params[:id])
  end

  def authorize_deck!
    authorize @deck
  end

  def deck_params
    params.require(:deck).permit(:title, :description, :category).tap do |permitted|
      permitted[:category] = Deck.category_key_for_code(permitted[:category]) if permitted[:category].present?
    end
  end

  def filter_by_category(scope)
    return scope unless @selected_category

    scope.where(category: @selected_category)
  end

  def order_for_index(scope, fallback_order)
    return scope.order(fallback_order) unless authenticated?

    join_sql = ActiveRecord::Base.sanitize_sql_array(
      [
        "LEFT OUTER JOIN deck_bookmarks deck_bookmarks_for_order ON " \
        "deck_bookmarks_for_order.deck_id = decks.id AND deck_bookmarks_for_order.user_id = ?",
        Current.user.id
      ]
    )

    scope
      .joins(join_sql)
      .order(Arel.sql("CASE WHEN deck_bookmarks_for_order.id IS NULL THEN 1 ELSE 0 END"))
      .order(fallback_order)
  end

  def deck_tab_value(value)
    return "personal" if value == "personal"
    return "bookmarked" if value == "bookmarked"

    "official"
  end

  def bookmarked_decks_for_index
    scope = Deck
      .joins(:deck_bookmarks)
      .where(deck_bookmarks: { user_id: Current.user.id })
      .where(
        "decks.scope = :official OR " \
        "(decks.scope = :personal AND decks.owner_type = :owner_type AND decks.owner_id = :owner_id)",
        official: Deck.scopes[:official],
        personal: Deck.scopes[:personal],
        owner_type: "User",
        owner_id: Current.user.id
      )

    filter_by_category(scope)
      .includes(:cards)
      .order(Arel.sql("deck_bookmarks.created_at DESC"))
  end

  def set_personal_deck_limit_state
    @personal_deck_count = Current.user.personal_deck_count
    @personal_deck_limit = Current.user.personal_deck_limit
    @pending_deck_addition_request = Current.user.pending_deck_addition_request
  end

  # Determines scope and owner explicitly — never trust raw params for these.
  # Permitted: club (if owner_id provided) or personal (default).
  # Official scope can only be set by site_admin; all others fall through to personal.
  def resolved_scope_and_owner
    requested_scope = params.dig(:deck, :scope)

    if requested_scope == "club"
      club = Club.find_by(id: params.dig(:deck, :owner_id))
      return { scope: :club, owner: club } if club
    end

    { scope: :personal, owner: Current.user }
  end
end
