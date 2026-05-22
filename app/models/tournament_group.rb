class TournamentGroup < ApplicationRecord
  belongs_to :tournament_event
  has_many :tournament_group_teams, dependent: :destroy
  has_many :teams, through: :tournament_group_teams, source: :tournament_team
  has_many :matches, as: :matchable, dependent: :destroy

  validates :name, presence: true
end
