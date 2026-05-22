class TournamentGroupPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  def create?
    return false unless user.present?
    tournament_manager?
  end

  def update? = create?
  def edit?   = update?
  def destroy? = create?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  private

  def tournament_manager? = club_manager?(record.tournament_event.tournament.club)
end
