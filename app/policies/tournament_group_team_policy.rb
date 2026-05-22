class TournamentGroupTeamPolicy < ApplicationPolicy
  def create?
    return false unless user.present?
    tournament_manager?
  end

  def destroy? = create?

  private

  def tournament_manager? = club_manager?(record.tournament_group.tournament_event.tournament.club)
end
