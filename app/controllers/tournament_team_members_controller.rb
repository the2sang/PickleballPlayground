class TournamentTeamMembersController < ApplicationController
  before_action :set_team,   only: %i[create]
  before_action :set_member, only: %i[destroy]

  def create
    @member = @team.tournament_team_members.build(member_params)
    authorize @member
    if @member.save
      redirect_to @team, notice: "팀원이 추가되었습니다."
    else
      redirect_to @team, alert: @member.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @member
    team = @member.tournament_team
    @member.destroy!
    redirect_to team, notice: "팀원이 삭제되었습니다."
  end

  private

  def set_team   = @team   = TournamentTeam.find(params[:tournament_team_id])
  def set_member = @member = TournamentTeamMember.find(params[:id])

  def member_params
    params.require(:tournament_team_member).permit(:user_id)
  end
end
