class FlashMeetupParticipationPolicy < ApplicationPolicy
  # 자격 검증(eligible?)은 서비스에서 처리. 정책은 인증/프로필 완료만 확인.
  def create?
    user.present? && user.profile_complete?
  end

  def destroy?
    return false unless user.present?
    return false if record.cancelled?

    site_admin? || record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.where(user: user)
    end
  end
end
