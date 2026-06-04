class GameSessionPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  def create?
    return false unless user.present?
    club_manager?(record.club)
  end

  def update? = create?
  def edit?   = update?
  def destroy? = site_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.nil?
        scope.where(visibility: :public_visibility).open
      elsif user.admin?
        scope.all
      else
        approved_club_ids = user.club_memberships.approved.select(:club_id)
        scope.open.where(
          "visibility = ? OR club_id IN (?)",
          GameSession.visibilities[:public_visibility],
          approved_club_ids
        )
      end
    end
  end
end
