module Admin
  class DataManagementPolicy < ApplicationPolicy
    def show?   = user.present? && user.role_admin?
    def execute? = user.present? && user.role_admin?
  end
end
