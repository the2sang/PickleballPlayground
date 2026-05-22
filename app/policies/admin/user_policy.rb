module Admin
  class UserPolicy < ApplicationPolicy
    def index?  = user&.role_admin?
    def show?   = user&.role_admin?
    def update? = user&.role_admin?

    class Scope < ApplicationPolicy::Scope
      def resolve
        user&.role_admin? ? scope.all : scope.none
      end
    end
  end
end
