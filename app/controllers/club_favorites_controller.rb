class ClubFavoritesController < ApplicationController
  before_action :require_authentication
  before_action :set_club

  rescue_from Pundit::NotAuthorizedError, with: :favorite_forbidden

  def create
    @favorite = ClubFavorite.find_or_initialize_by(user: Current.user, club: @club)
    authorize @favorite
    @favorite.save!
    set_favorite_view_vars
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path }
    end
  end

  def destroy
    @favorite = ClubFavorite.find_by!(user: Current.user, club: @club)
    authorize @favorite
    @favorite.destroy!
    set_favorite_view_vars
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clubs_path }
    end
  end

  private

  def set_club = @club = Club.find(params[:club_id])

  def set_favorite_view_vars
    @favorited_club_ids = Current.user.club_favorites.pluck(:club_id).to_set
    @member_club_ids    = Current.user.club_memberships
                                       .where(status: %i[pending approved])
                                       .pluck(:club_id).to_set
  end

  def favorite_forbidden
    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.html         { redirect_to clubs_path, alert: "접근 권한이 없습니다." }
    end
  end
end
