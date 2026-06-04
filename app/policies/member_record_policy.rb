class MemberRecordPolicy < ApplicationPolicy
  def index?  = user&.admin?
  def new?    = user&.admin?
  def create? = user&.admin?
  def edit?   = user&.admin?
  def update? = user&.admin?
  def destroy? = user&.admin?
  def template? = user&.admin?
  def import?   = user&.admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
