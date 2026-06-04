class CreateTournamentTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_teams do |t|
      t.integer :tournament_event_id, null: false
      t.string  :name, null: false
      t.integer :seed

      t.timestamps
    end

    add_index :tournament_teams, :tournament_event_id
  end
end
