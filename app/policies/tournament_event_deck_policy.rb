class TournamentEventDeckPolicy < ApplicationPolicy
  # Phase 1 stub: all actions default-deny via ApplicationPolicy.
  # Phase 5 wires real rules.

  class Scope < ApplicationPolicy::Scope
    def resolve
      # TODO(phase-5): allow event organizers / admins to view event's decks
      scope.none
    end
  end
end
