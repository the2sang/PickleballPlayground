class CardReview < ApplicationRecord
  belongs_to :user
  belongs_to :card
  # Minimal stub — full validations (uniqueness, ease floor, last_rating range)
  # land in Task 2.3.
end
