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
    site_admin? || (record.draft? && club_manager?(record.club))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end
end
