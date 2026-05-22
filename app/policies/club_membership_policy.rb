class ClubMembershipPolicy < ApplicationPolicy
  def create? = user.present?

  def update?
    return false unless user.present?
    club_manager?(record.club)
  end

  def destroy?
    user.present? && (user == record.user || update?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end
end
