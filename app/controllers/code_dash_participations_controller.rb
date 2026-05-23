class CodeDashParticipationsController < ApplicationController
  MAX_FAILED_ATTEMPTS = 3

  allow_unauthenticated_access only: :create
  before_action :resume_session, only: :create
  before_action :set_game_session
  rate_limit to: 10, within: 10.minutes, only: :create,
             with: -> { redirect_to game_session_path(@game_session), alert: "잠시 후 다시 시도해 주세요." }

  def create
    user = User.find_by_code_dash_key(params[:code_dash_key])

    if user && club_member?(user)
      create_participation_for(user)
    else
      handle_failed_attempt
    end
  end

  private

  def set_game_session
    @game_session = GameSession.includes(:club).find(params[:game_session_id])
  end

  def club_member?(user)
    user.club_memberships
      .where(club: @game_session.club, status: %i[pending approved])
      .exists?
  end

  def create_participation_for(user)
    reset_failed_attempts
    switch_session_to(user)
    user.update!(code_dash_key_last_used_at: Time.current)

    result = Participations::CreateService.call(
      game_session: @game_session,
      user: user,
      participation_type: :as_member
    )

    if result.success?
      message = result.participation.waitlisted? ? "대기열에 등록되었습니다." : "참가 신청이 완료되었습니다."
      redirect_to game_session_path(@game_session), notice: message
    else
      redirect_to game_session_path(@game_session), alert: result.errors.join(", ")
    end
  end

  def switch_session_to(user)
    return if Current.user == user

    terminate_session if Current.session.present?
    start_new_session_for(user)
  end

  def handle_failed_attempt
    attempts = increment_failed_attempts

    if attempts >= MAX_FAILED_ATTEMPTS
      reset_failed_attempts
      redirect_to new_session_path(return_to: game_session_path(@game_session)),
                  alert: "접속키 입력 실패가 3회 발생했습니다. 로그인으로 인증해 주세요."
    else
      remaining = MAX_FAILED_ATTEMPTS - attempts
      redirect_to game_session_path(@game_session, code_dash: 1),
                  alert: "접속키를 확인해 주세요. #{remaining}회 더 실패하면 로그인 인증이 필요합니다."
    end
  end

  def increment_failed_attempts
    attempts = failed_attempts
    attempts[@game_session.id.to_s] = attempts.fetch(@game_session.id.to_s, 0) + 1
    session[:code_dash_participation_failed_attempts] = attempts
    attempts[@game_session.id.to_s]
  end

  def reset_failed_attempts
    attempts = failed_attempts
    attempts.delete(@game_session.id.to_s)
    session[:code_dash_participation_failed_attempts] = attempts
  end

  def failed_attempts
    session[:code_dash_participation_failed_attempts] ||= {}
  end
end
