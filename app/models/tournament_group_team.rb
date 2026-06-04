class TournamentGroupTeam < ApplicationRecord
  belongs_to :tournament_group
  belongs_to :tournament_team

  validates :tournament_group_id, uniqueness: { scope: :tournament_team_id }
end
