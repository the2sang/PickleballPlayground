class TournamentGroupTeamsController < ApplicationController
  before_action :set_group,      only: %i[create]
  before_action :set_group_team, only: %i[destroy]

  def create
    @group_team = @group.tournament_group_teams.build(group_team_params)
    authorize @group_team
    if @group_team.save
      redirect_to @group, notice: "팀이 조에 배정되었습니다."
    else
      redirect_to @group, alert: @group_team.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @group_team
    group = @group_team.tournament_group
    @group_team.destroy!
    redirect_to group, notice: "팀이 조에서 제거되었습니다."
  end

  private

  def set_group      = @group      = TournamentGroup.find(params[:tournament_group_id])
  def set_group_team = @group_team = TournamentGroupTeam.find(params[:id])

  def group_team_params
    params.require(:tournament_group_team).permit(:tournament_team_id)
  end
end
