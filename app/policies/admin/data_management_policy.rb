module Admin
  class DataManagementPolicy < ApplicationPolicy
    def show?   = user.present? && user.admin?
    def execute? = user.present? && user.admin?
    def create_backup? = user.present? && user.admin?
    def create_postgresql_backup? = user.present? && user.admin?
    def restore_backup? = user.present? && user.admin?
    def download_backup? = user.present? && user.admin?
  end
end
