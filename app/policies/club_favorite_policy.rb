class ClubFavoritePolicy < ApplicationPolicy
  def create?
    user.present? &&
      user.club_memberships.where(club: record.club, status: %i[pending approved]).exists?
  end

  def destroy?
    user.present? && record.user == user
  end
end
