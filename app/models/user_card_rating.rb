class UserCardRating < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :difficulty, presence: true,
                         numericality: { only_integer: true,
                                         greater_than_or_equal_to: 1,
                                         less_than_or_equal_to: 5 }
  validates :card_id, uniqueness: { scope: :user_id }
end
