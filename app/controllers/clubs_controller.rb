class ClubsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session,  only: %i[index show]
  before_action :set_club,        only: %i[show edit update destroy manage]

  def index
    clubs = policy_scope(Club)
    if Current.user
      fav_ids = Current.user.club_favorites.pluck(:club_id)
      @member_club_ids    = Current.user.club_memberships
                                         .where(status: %i[pending approved])
                                         .pluck(:club_id).to_set
      @favorited_club_ids = fav_ids.to_set
      @clubs = if fav_ids.any?
        clubs.order(
          Arel.sql("CASE WHEN id IN (#{fav_ids.join(',')}) THEN 0 ELSE 1 END, name ASC")
        )
      else
        clubs.order(:name)
      end
    else
      @member_club_ids    = Set.new
      @favorited_club_ids = Set.new
      @clubs = clubs.order(:name)
    end
  end

  def show
    authorize @club
    @game_sessions = policy_scope(GameSession).where(club: @club).order(scheduled_date: :desc)
  end

  def new
    @club = Club.new
    authorize @club
  end

  def create
    @club = Club.new(club_params.merge(owner: Current.user, status: :approved))
    authorize @club
    if @club.save
      @club.club_memberships.create!(user: Current.user, role: :manager, status: :approved)
      Clubs::AssignManagerByEmailService.call(club: @club)
      redirect_to @club, notice: "동호회가 개설되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def manage
    authorize @club, :manage?
    @pending_memberships  = @club.club_memberships.pending.includes(:user)
    @approved_memberships = @club.club_memberships.approved.includes(:user).order("role DESC")
    @game_sessions        = @club.game_sessions.order(scheduled_date: :desc).limit(20)
    @guest_applications   = @club.guest_applications.order(created_at: :desc)
  end

  def edit
    authorize @club
  end

  def update
    authorize @club
    if @club.update(club_params)
      redirect_to @club, notice: "동호회 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @club
    @club.destroy!
    redirect_to clubs_path, notice: "동호회가 삭제되었습니다."
  end

  private

  def set_club = @club = Club.find(params[:id])
  def club_params = params.require(:club).permit(:name, :description, :contact_phone, :contact_email)
end
