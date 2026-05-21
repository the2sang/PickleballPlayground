class CreateTournamentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_events do |t|
      t.integer :tournament_id, null: false
      t.integer :discipline, null: false
      t.integer :advances_per_group, default: 2, null: false
      t.integer :scoring_format, default: 0, null: false
      t.integer :points_to_win, default: 11, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :tournament_events, :tournament_id
    add_index :tournament_events, :status
  end
end
