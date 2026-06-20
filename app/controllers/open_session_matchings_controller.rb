class OpenSessionMatchingsController < ApplicationController
  before_action :set_game_session

  def show
    authorize @game_session, :create_matching?

    @participants = @game_session.participations.confirmed.includes(:user).order(:created_at)
    @plan = OpenSessions::MatchPlanBuilder.new(
      game_session: @game_session,
      mode: params[:mode],
      rounds: params[:rounds],
      fixed_user_id: params[:fixed_user_id],
      fixed_partner_user_id: params[:fixed_partner_user_id],
      fixed_partner_starts_round: params[:fixed_partner_starts_round]
    ).call
  end

  private

  def set_game_session
    @game_session = GameSession.open_game.find(params[:game_session_id])
  end
end
