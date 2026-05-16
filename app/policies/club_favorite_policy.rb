class ClubFavoritePolicy < ApplicationPolicy
  def create?
    return false unless user.present?

    membership = user.club_memberships.find_by(club: record.club)
    membership&.approved? || membership&.pending?
  end

  def destroy?
    user.present? && record.user == user
  end
end
