class MemberRecordPolicy < ApplicationPolicy
  def index?  = user&.role_admin?
  def new?    = user&.role_admin?
  def create? = user&.role_admin?
  def edit?   = user&.role_admin?
  def update? = user&.role_admin?
  def destroy? = user&.role_admin?
  def template? = user&.role_admin?
  def import?   = user&.role_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.role_admin? ? scope.all : scope.none
  end
end
