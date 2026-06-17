class GameSessionsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session,   only: %i[index show]
  before_action :set_club,         only: %i[new create]
  before_action :set_game_session, only: %i[show edit update destroy]

  def index
    @query = params[:q].presence
    sessions = policy_scope(GameSession)
      .regular
      .joins(:club)
      .includes(:club)
      .order("clubs.name ASC, scheduled_date ASC, start_time ASC")
    sessions = sessions.where("clubs.name LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%") if @query

    favorited_ids = Current.user ? Current.user.club_favorites.pluck(:club_id).to_set : Set.new
    @game_sessions_by_club = sessions.group_by(&:club).sort_by { |club, _| favorited_ids.include?(club.id) ? 0 : 1 }.to_h
  end

  def show
    authorize @game_session

    participant_user_ids = @game_session.participations.map(&:user_id).compact
    lookup_user_ids = Current.user ? (participant_user_ids | [ Current.user.id ]) : participant_user_ids
    memberships = ClubMembership.where(club: @game_session.club, user_id: lookup_user_ids)
    @membership_map = memberships.index_by(&:user_id)

    if Current.user
      my_membership = @membership_map[Current.user.id]
      @is_manager = (my_membership&.manager? && my_membership&.approved?) || Current.user.admin?
    end

    @club_notices = @game_session.club.club_notices.recent.limit(10)
  end

  def new
    @game_session = @club.game_sessions.build(session_type: new_session_type)
    authorize @game_session
  end

  def create
    @game_session = @club.game_sessions.build(game_session_params)
    authorize @game_session
    if @game_session.save
      redirect_to @game_session, notice: "세션이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @game_session
  end

  def update
    authorize @game_session
    if @game_session.update(game_session_params)
      redirect_to @game_session, notice: "세션이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @game_session
    club = @game_session.club
    @game_session.destroy!
    redirect_to club_path(club), notice: "세션이 삭제되었습니다."
  end

  private

  def set_club = @club = Club.find(params[:club_id])

  def new_session_type
    GameSession.session_types.key?(params[:session_type]) ? params[:session_type] : :regular
  end
  def set_game_session
    @game_session = GameSession.includes(participations: :user).find(params[:id])
  end

  def game_session_params
    p = params.require(:game_session).permit(
      :title, :venue_name, :address, :scheduled_date,
      :start_time, :end_time, :court_count, :court_name, :level, :session_type, :fee, :notes,
      :max_participants, :max_waitlist, :visibility, :status,
      :repeat_type, :repeat_ends_on, repeat_days: []
    )
    # 체크박스 배열을 쉼표 구분 문자열로 변환
    if p[:repeat_days].present?
      p[:repeat_days] = p[:repeat_days].map(&:to_s).join(",")
    end
    p
  end
end
