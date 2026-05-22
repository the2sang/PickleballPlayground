class CreateTournamentTeamMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_team_members do |t|
      t.integer :tournament_team_id, null: false
      t.integer :user_id, null: false

      t.timestamps
    end

    add_index :tournament_team_members, :tournament_team_id
    add_index :tournament_team_members, :user_id
    add_index :tournament_team_members, [ :tournament_team_id, :user_id ], unique: true
  end
end
