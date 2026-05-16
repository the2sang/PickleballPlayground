class ClubFavoritesController < ApplicationController
  before_action :require_authentication
  before_action :set_club

  rescue_from Pundit::NotAuthorizedError, with: :favorite_forbidden

  def create
    @favorite = ClubFavorite.find_or_initialize_by(user: Current.user, club: @club)
    authorize @favorite
    @favorite.save!
    flash[:success] = "즐겨찾기가 추가되었습니다."
    redirect_to clubs_path
  end

  def destroy
    @favorite = ClubFavorite.find_by!(user: Current.user, club: @club)
    authorize @favorite
    @favorite.destroy!
    flash[:success] = "즐겨찾기가 해제되었습니다."
    redirect_to clubs_path
  end

  private

  def set_club = @club = Club.find(params[:club_id])

  def favorite_forbidden
    redirect_to clubs_path, alert: "접근 권한이 없습니다."
  end
end
