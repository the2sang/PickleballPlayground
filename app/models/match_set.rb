class MatchSet < ApplicationRecord
  belongs_to :match

  validates :set_number, presence: true
  validates :home_score, numericality: { greater_than_or_equal_to: 0 }
  validates :away_score, numericality: { greater_than_or_equal_to: 0 }
end
