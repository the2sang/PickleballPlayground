module Admin
  class SiteSettingPolicy < ApplicationPolicy
    def update? = user&.admin?
  end
end
