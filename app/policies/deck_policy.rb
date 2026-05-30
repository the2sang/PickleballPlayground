class DeckPolicy < ApplicationPolicy
  # Phase 1 stubs. Real rules in Phase 4.
  # The minimum to make Phase 2 personal-deck CRUD work:

  def show?
    return true if record.official?
    return personal_owner? if record.personal?
    return false unless user.present?
    user.club_memberships.approved.exists?(club_id: record.owner_id)
  end
  def create?  = user.present?
  def new?     = create?
  def update?  = personal_owner?
  def edit?    = update?
  def destroy? = personal_owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      # TODO(phase-4): implement 3-tier official ∪ club(approved) ∪ personal(owner) resolver
      scope.none
    end
  end

  private

  def personal_owner?
    return false unless user.present?
    return true  if site_admin?            # bypass — matches ClubPolicy precedent
    record.respond_to?(:owner) && record.owner == user
  end
end
