class OpenGameSessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def index
    @query = params[:q].presence
    sessions = policy_scope(GameSession)
      .open_game
      .joins(:club)
      .includes(:club, participations: :user)
      .where.not(status: :cancelled)
      .order(scheduled_date: :desc, start_time: :desc, id: :desc)
    sessions = sessions.where("clubs.name LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%") if @query

    favorited_ids = Current.user ? Current.user.club_favorites.pluck(:club_id).to_set : Set.new
    @game_sessions_by_club = sessions.group_by(&:club)
                                     .sort_by { |club, _| favorited_ids.include?(club.id) ? 0 : 1 }
                                     .to_h
  end
end
