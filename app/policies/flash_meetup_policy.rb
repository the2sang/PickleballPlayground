class FlashMeetupPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  def create?
    user.present? && user.profile_complete?
  end

  def update? = organizer_or_admin?
  def edit?   = update?
  def destroy? = organizer_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.upcoming
    end
  end

  private

  def organizer_or_admin?
    user.present? && (record.user == user || site_admin?)
  end
end
