class TournamentEventDeck < ApplicationRecord
  belongs_to :tournament_event
  belongs_to :deck

  validates :deck_id, uniqueness: { scope: :tournament_event_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
