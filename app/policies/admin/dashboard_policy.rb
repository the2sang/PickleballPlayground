module Admin
  class DashboardPolicy < ApplicationPolicy
    def index? = user&.role_admin?
  end
end
