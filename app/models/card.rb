class Card < ApplicationRecord
  belongs_to :deck
  # Minimal stub — full model (validations, ActiveStorage attachments,
  # cascade on card_reviews, ordered scope) lands in Task 2.2.
end
