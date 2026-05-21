class TournamentGroupTeamPolicy < ApplicationPolicy
  def create?
    return false unless user.present?
    tournament_manager?
  end

  def destroy? = create?

  private

  def tournament_manager?
    club = record.tournament_group.tournament_event.tournament.club
    return true if user.admin?
    return true if club.owner_id == user.id
    membership = user.club_memberships.find_by(club: club)
    membership.present? && membership.manager? && membership.approved?
  end
end
