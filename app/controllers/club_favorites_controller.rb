class ClubFavoritesController < ApplicationController
  before_action :require_authentication
  before_action :set_club

  rescue_from Pundit::NotAuthorizedError, with: :favorite_forbidden

  def create
    @favorite = ClubFavorite.find_or_initialize_by(user: Current.user, club: @club)
    authorize @favorite
    @favorite.save!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path }
    end
  end

  def destroy
    @favorite = ClubFavorite.find_by!(user: Current.user, club: @club)
    authorize @favorite
    @favorite.destroy!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path }
    end
  end

  private

  def set_club
    @club = Club.find(params[:club_id])
  end

  def favorite_forbidden
    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.html         { redirect_to clubs_path, alert: "접근 권한이 없습니다." }
    end
  end
end
