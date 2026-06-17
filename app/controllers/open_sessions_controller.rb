class OpenSessionsController < ApplicationController
  allow_unauthenticated_access only: :index
  before_action :resume_session, only: :index
  before_action :set_club

  # 클럽 단위 오픈 게임 세션 페이지. 코트별 세션을 날짜/시간 순으로 보여준다.
  def index
    sessions = @club.game_sessions.open_game.where.not(status: :cancelled)
    sessions = sessions.where(visibility: :public_visibility) unless viewer_sees_members_only?

    @game_sessions = sessions.includes(participations: :user)
                             .order(:scheduled_date, :start_time, :court_name)
    @can_manage = GameSessionPolicy.new(Current.user, @club.game_sessions.build(session_type: :open_game)).create?
  end

  def create
    @game_session = params[:copy_from].present? ? copy_last_session : build_session
    authorize @game_session, :create?

    if @game_session.save
      redirect_to club_open_sessions_path(@club), notice: "세션이 추가되었습니다."
    else
      redirect_to club_open_sessions_path(@club),
                  alert: @game_session.errors.full_messages.to_sentence
    end
  end

  private

  def set_club = @club = Club.find(params[:club_id])

  def build_session
    @club.game_sessions.build(open_session_params.merge(session_type: :open_game))
  end

  # "세션 추가": 마지막 세션을 복사하되 코트명과 참가자는 초기화한다.
  def copy_last_session
    source = @club.game_sessions.open_game.find(params[:copy_from])
    @club.game_sessions.build(
      title:            source.title,
      venue_name:       source.venue_name,
      address:          source.address,
      scheduled_date:   source.scheduled_date,
      start_time:       source.start_time,
      end_time:         source.end_time,
      level:            source.level,
      max_participants: source.max_participants,
      max_waitlist:     source.max_waitlist,
      visibility:       source.visibility,
      session_type:     :open_game,
      status:           :open,
      court_name:       nil
    )
  end

  def open_session_params
    params.require(:game_session).permit(
      :title, :venue_name, :address, :scheduled_date, :start_time, :end_time,
      :level, :court_name, :max_participants, :max_waitlist, :visibility, :notes
    )
  end

  # 회원전용 세션을 볼 수 있는 뷰어인지(관리자/소유자/승인된 회원)
  def viewer_sees_members_only?
    return false unless Current.user
    return true if Current.user.admin? || @club.owner_id == Current.user.id

    Current.user.club_memberships.find_by(club: @club)&.approved?
  end
end
