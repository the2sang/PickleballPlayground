class ClubNotice < ApplicationRecord
  belongs_to :club

  validates :title, presence: true, length: { maximum: 80 }
  validates :body, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
