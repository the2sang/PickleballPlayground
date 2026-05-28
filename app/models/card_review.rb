class CardReview < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :card_id, uniqueness: { scope: :user_id }
  validates :ease,          numericality: { greater_than_or_equal_to: 1.3 }
  validates :interval_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :repetitions,   numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :last_rating,   numericality: { only_integer: true, in: 1..4 }, allow_nil: true
end
