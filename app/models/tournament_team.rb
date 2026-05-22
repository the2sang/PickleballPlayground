class TournamentTeam < ApplicationRecord
  belongs_to :tournament_event
  has_many :tournament_team_members, dependent: :destroy
  has_many :users, through: :tournament_team_members
  has_many :tournament_group_teams, dependent: :destroy

  validates :name, presence: true

  def auto_name_from_members
    users.pluck(:nickname).join(" / ")
  end
end
