class TournamentEventsController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :resume_session,  only: %i[show]
  before_action :set_tournament,  only: %i[new create]
  before_action :set_event,       only: %i[show edit update destroy generate_groups generate_bracket]

  def show
    authorize @event
    @teams  = @event.tournament_teams.includes(:users)
    @groups = @event.tournament_groups
                    .includes(tournament_group_teams: { tournament_team: :users })
    @bracket_matches = Match.where(matchable: @event)
                            .includes(:home_team, :away_team, :winner)
                            .order(:round, :match_number)
  end

  def new
    @event = @tournament.tournament_events.build
    authorize @event
  end

  def create
    @event = @tournament.tournament_events.build(event_params)
    authorize @event
    if @event.save
      redirect_to @event, notice: "종목이 추가되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @event
  end

  def update
    authorize @event
    if @event.update(event_params)
      redirect_to @event, notice: "종목 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @event
    tournament = @event.tournament
    @event.destroy!
    redirect_to tournament, notice: "종목이 삭제되었습니다."
  end

  def generate_groups
    authorize @event, :update?
    result = TournamentGroups::AutoAssignService.call(
      tournament_event: @event,
      group_count: params[:group_count].to_i
    )
    if result.success?
      redirect_to @event, notice: "조 편성이 완료되었습니다."
    else
      redirect_to @event, alert: result.error
    end
  end

  def generate_bracket
    authorize @event, :update?
    result = TournamentBracket::GenerateService.call(tournament_event: @event)
    if result.success?
      redirect_to @event, notice: "본선 대진이 생성되었습니다."
    else
      redirect_to @event, alert: result.error
    end
  end

  private

  def set_tournament = @tournament = Tournament.find(params[:tournament_id])
  def set_event      = @event      = TournamentEvent.find(params[:id])

  def event_params
    params.require(:tournament_event).permit(
      :discipline, :sub_category, :scoring_format, :points_to_win, :advances_per_group
    )
  end
end
