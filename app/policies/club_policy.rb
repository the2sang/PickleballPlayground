class ClubPolicy < ApplicationPolicy
  def index?  = true
  def show?   = record.approved? || (user.present? && user == record.owner)
  def new?    = true
  def create? = true
  def manage?
    return false unless user.present?
    club_manager?(record)
  end

  def update? = user.present? && (user == record.owner || site_admin?)
  def edit?   = update?
  def destroy? = site_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.approved
    end
  end
end
