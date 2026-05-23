class CodeDashSessionsController < ApplicationController
  allow_unauthenticated_access only: :create
  before_action :resume_session, only: :create
  before_action :set_club
  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to club_path(@club), alert: "잠시 후 다시 시도해 주세요." }

  def create
    user = User.find_by_code_dash_key(params[:code_dash_key])

    if user && approved_for_club?(user)
      unless Current.user == user
        terminate_session if Current.session.present?
        start_new_session_for(user)
      end
      user.update!(code_dash_key_last_used_at: Time.current)
      redirect_to club_path(@club), notice: "codedash로 접속했습니다."
    else
      redirect_to club_path(@club), alert: "고유키를 확인해 주세요."
    end
  end

  private

  def set_club
    @club = Club.approved.find(params[:club_id])
  end

  def approved_for_club?(user)
    @club.owner_id == user.id ||
      user.club_memberships.approved.exists?(club: @club)
  end
end
