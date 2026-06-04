class TournamentTeamMember < ApplicationRecord
  belongs_to :tournament_team
  belongs_to :user

  validates :tournament_team_id, uniqueness: { scope: :user_id }
end
