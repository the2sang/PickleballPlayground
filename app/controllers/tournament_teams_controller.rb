class TournamentTeamsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_event,      only: %i[index new create]
  before_action :set_team,       only: %i[show edit update destroy]
  before_action :set_event_from_team, only: %i[edit update]

  def index
    authorize TournamentTeam
    @teams = policy_scope(TournamentTeam)
               .where(tournament_event: @event)
               .includes(:users)
               .order(:seed, :name)
  end

  def show
    authorize @team
    @members = @team.tournament_team_members.includes(:user)
  end

  def new
    @team = @event.tournament_teams.build
    @club_members = @event.tournament.club.club_memberships.approved.includes(:user)
                          .map { |m| { id: m.user.id, nickname: m.user.nickname } }
    authorize @team
  end

  def create
    authorize @event.tournament_teams.build, :create?
    entries = bulk_team_params.reject { |t| t[:name].blank? }
    if entries.empty?
      @club_members = []
      @teams = Array.new(4) { @event.tournament_teams.build }
      flash.now[:alert] = "팀명을 하나 이상 입력하세요."
      return render :new, status: :unprocessable_entity
    end
    TournamentTeam.transaction do
      entries.each do |entry|
        team = @event.tournament_teams.create!(
          name: entry[:name], seed: entry[:seed].presence,
          player_names: entry[:player_names].presence
        )
        Array(entry[:player_user_ids]).reject(&:blank?).each do |uid|
          team.tournament_team_members.create!(user_id: uid)
        end
      end
    end
    redirect_to tournament_event_tournament_teams_path(@event), notice: "#{entries.size}개 팀이 등록되었습니다."
  end

  def edit
    authorize @team
  end

  def update
    authorize @team
    if @team.update(team_params)
      redirect_to tournament_event_tournament_teams_path(@team.tournament_event), notice: "팀 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @team
    event = @team.tournament_event
    @team.destroy!
    redirect_to tournament_event_tournament_teams_path(event), notice: "팀이 삭제되었습니다."
  end

  private

  def set_event           = @event = TournamentEvent.find(params[:tournament_event_id])
  def set_team            = @team  = TournamentTeam.find(params[:id])
  def set_event_from_team = @event = @team.tournament_event

  def team_params
    params.require(:tournament_team).permit(:name, :seed)
  end

  def bulk_team_params
    raw = params.permit(teams: [ :name, :seed, :player_names, { player_user_ids: [] } ])[:teams]
    return [] if raw.nil?
    raw.is_a?(Array) ? raw : raw.values
  end
end
