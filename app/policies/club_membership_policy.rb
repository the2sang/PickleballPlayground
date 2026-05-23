class ClubMembershipPolicy < ApplicationPolicy
  def create? = user.present?

  def update?
    return false unless user.present?
    return true if club_manager?(record.club)
    return true if user == record.user && withdrawal_status_change?
    false
  end

  def destroy?
    user.present? && (user == record.user || club_manager?(record.club))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def withdrawal_status_change?
    allowed = %w[approved withdrawal_requested]
    allowed.include?(record.status_was) && allowed.include?(record.status)
  end
end
