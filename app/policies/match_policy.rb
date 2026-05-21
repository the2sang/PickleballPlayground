class MatchPolicy < ApplicationPolicy
  def index? = true
  def show?  = true

  def update?
    return false unless user.present?
    return false if record.locked?
    tournament_manager?
  end

  def edit? = update?

  private

  def tournament_manager?
    club = club_for_match(record)
    return true if user.admin?
    return true if club.owner_id == user.id
    membership = user.club_memberships.find_by(club: club)
    membership.present? && membership.manager? && membership.approved?
  end

  def club_for_match(match)
    case match.matchable
    when TournamentGroup then match.matchable.tournament_event.tournament.club
    when TournamentEvent then match.matchable.tournament.club
    end
  end
end
