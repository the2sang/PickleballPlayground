module Admin
  class DataManagementPolicy < ApplicationPolicy
    def show?   = user.present? && user.role_admin?
    def execute? = user.present? && user.role_admin?
    def create_backup? = user.present? && user.role_admin?
    def restore_backup? = user.present? && user.role_admin?
    def download_backup? = user.present? && user.role_admin?
  end
end
