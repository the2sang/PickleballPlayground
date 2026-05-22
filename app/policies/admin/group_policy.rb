module Admin
  class GroupPolicy < ApplicationPolicy
    def index?   = user.role_admin?
    def show?    = user.role_admin?
    def create?  = user.role_admin?
    def new?     = create?
    def update?  = user.role_admin?
    def edit?    = update?
    def destroy? = user.role_admin?
  end
end
