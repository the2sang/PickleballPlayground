class AddPlayerNamesToTournamentTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :tournament_teams, :player_names, :string
  end
end
