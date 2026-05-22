module Admin
  class SessionPolicy < ApplicationPolicy
    def index? = user&.role_admin?

    class Scope < ApplicationPolicy::Scope
      def resolve
        user&.role_admin? ? scope.all : scope.none
      end
    end
  end
end
