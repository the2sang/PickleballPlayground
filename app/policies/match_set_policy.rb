class MatchSetPolicy < ApplicationPolicy
  def create?
    return false unless user.present?
    tournament_manager?
  end

  def update? = create?
  def edit?   = update?
  def destroy? = create?

  private

  def tournament_manager? = club_manager?(club_for_match(record.match))

  def club_for_match(match)
    case match.matchable
    when TournamentGroup then match.matchable.tournament_event.tournament.club
    when TournamentEvent then match.matchable.tournament.club
    end
  end
end
