class ParticipationPolicy < ApplicationPolicy
  def create?
    user.present? && user.profile_complete?
  end

  def destroy?
    return false if record.cancelled?
    return false unless user.present?
    return true if club_manager?(record.game_session.club) || site_admin?
    user == record.user && !record.game_session.session_ended?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.role_admin? ? scope.all : scope.where(user: user)
    end
  end
end
