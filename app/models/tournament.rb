class Tournament < ApplicationRecord
  belongs_to :club
  has_many :tournament_events, dependent: :destroy

  enum :status, { draft: 0, in_progress: 1, completed: 2 }, default: :draft

  validates :name, presence: true
  validates :club, presence: true
end
