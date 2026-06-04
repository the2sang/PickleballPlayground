class CreateTournamentGroupTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_group_teams do |t|
      t.integer :tournament_group_id, null: false
      t.integer :tournament_team_id, null: false

      t.timestamps
    end

    add_index :tournament_group_teams, :tournament_group_id
    add_index :tournament_group_teams, :tournament_team_id
    add_index :tournament_group_teams, [ :tournament_group_id, :tournament_team_id ], unique: true
  end
end
