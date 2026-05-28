class ClubNoticePolicy < ApplicationPolicy
  def new? = create?
  def create? = club_manager?(record.club)
  def edit? = update?
  def update? = club_manager?(record.club)
  def destroy? = club_manager?(record.club)
end
