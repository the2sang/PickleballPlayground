class TournamentGroupsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_event,      only: %i[index new create]
  before_action :set_group,      only: %i[show edit update destroy]

  def index
    authorize TournamentGroup
    @groups = policy_scope(TournamentGroup)
                .where(tournament_event: @event)
                .includes(tournament_group_teams: { tournament_team: :users })
  end

  def show
    authorize @group
    @group_teams = @group.tournament_group_teams.includes(tournament_team: :users)
    @matches     = @group.matches
                         .includes(:home_team, :away_team, :winner, :match_sets)
                         .order(:match_number)
  end

  def new
    @group = @event.tournament_groups.build
    authorize @group
  end

  def create
    @group = @event.tournament_groups.build(group_params)
    authorize @group
    if @group.save
      redirect_to tournament_event_tournament_groups_path(@event), notice: "조가 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @group
  end

  def update
    authorize @group
    if @group.update(group_params)
      redirect_to @group, notice: "조 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @group
    event = @group.tournament_event
    @group.destroy!
    redirect_to tournament_event_tournament_groups_path(event), notice: "조가 삭제되었습니다."
  end

  private

  def set_event = @event = TournamentEvent.find(params[:tournament_event_id])
  def set_group = @group = TournamentGroup.find(params[:id])

  def group_params
    params.require(:tournament_group).permit(:name)
  end
end
