class TournamentsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session,    only: %i[index show]
  before_action :set_club,          only: %i[index new create]
  before_action :set_tournament,    only: %i[show edit update destroy advance_status]

  def index
    @tournaments = policy_scope(Tournament)
                     .where(club: @club)
                     .order(created_at: :desc)
  end

  def show
    authorize @tournament
    @events = @tournament.tournament_events
  end

  def new
    @tournament = @club.tournaments.build
    authorize @tournament
  end

  def create
    @tournament = @club.tournaments.build(tournament_params)
    authorize @tournament
    if @tournament.save
      redirect_to @tournament, notice: "대회가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @tournament
  end

  def update
    authorize @tournament
    if @tournament.update(tournament_params)
      redirect_to @tournament, notice: "대회 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @tournament
    club = @tournament.club
    @tournament.destroy!
    redirect_to club_tournaments_path(club), notice: "대회가 삭제되었습니다."
  end

  def advance_status
    authorize @tournament, :update?
    case @tournament.status
    when "draft"       then @tournament.in_progress!
    when "in_progress" then @tournament.completed!
    end
    redirect_to @tournament, notice: "대회 상태가 변경되었습니다."
  end

  private

  def set_club       = @club       = Club.find(params[:club_id])
  def set_tournament = @tournament = Tournament.find(params[:id])

  def tournament_params
    params.require(:tournament).permit(:name, :description, :starts_on, :ends_on)
  end
end
