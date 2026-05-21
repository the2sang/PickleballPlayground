class TournamentPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  def create?
    return false unless user.present?
    club_manager?(record.club)
  end

  def update? = create?
  def edit?   = update?

  def destroy?
    return false unless user.present?
    user.admin? || (record.draft? && club_manager?(record.club))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def club_manager?(club)
    return true if user.admin?
    return true if club.owner_id == user.id
    membership = user.club_memberships.find_by(club: club)
    membership.present? && membership.manager? && membership.approved?
  end
end
