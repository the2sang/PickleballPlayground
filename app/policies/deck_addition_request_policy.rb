class DeckAdditionRequestPolicy < ApplicationPolicy
  def create?
    user.present? && record.user == user
  end

  def update?
    site_admin?
  end
end
