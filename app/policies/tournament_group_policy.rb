class TournamentGroupPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  def create?
    return false unless user.present?
    tournament_manager?
  end

  def update? = create?
  def edit?   = update?
  def destroy? = create?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def tournament_manager?
    club = record.tournament_event.tournament.club
    return true if user.admin?
    return true if club.owner_id == user.id
    membership = user.club_memberships.find_by(club: club)
    membership.present? && membership.manager? && membership.approved?
  end
end
