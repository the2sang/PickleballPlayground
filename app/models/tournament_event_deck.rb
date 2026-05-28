class TournamentEventDeck < ApplicationRecord
  belongs_to :tournament_event
  belongs_to :deck
  # Minimal stub — uniqueness/position validations land in Task 2.4.
end
