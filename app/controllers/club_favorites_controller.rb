class ClubFavoritesController < ApplicationController
  before_action :require_authentication
  before_action :set_club

  rescue_from Pundit::NotAuthorizedError, with: :favorite_forbidden

  def create
    @favorite = ClubFavorite.find_or_initialize_by(user: Current.user, club: @club)
    authorize @favorite
    @favorite.save!
    set_user_club_data
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path, notice: "즐겨찾기가 추가되었습니다." }
    end
  end

  def destroy
    @favorite = ClubFavorite.find_by!(user: Current.user, club: @club)
    authorize @favorite
    @favorite.destroy!
    set_user_club_data
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path, notice: "즐겨찾기가 해제되었습니다." }
    end
  end

  private

  def set_club = @club = Club.find(params[:club_id])

  def set_user_club_data
    @favorited_club_ids = Current.user.club_favorites.pluck(:club_id).to_set
    @member_club_ids    = Current.user.club_memberships
                                       .where(status: %i[pending approved])
                                       .pluck(:club_id).to_set
  end

  def favorite_forbidden
    redirect_to clubs_path, alert: "접근 권한이 없습니다."
  end
end
