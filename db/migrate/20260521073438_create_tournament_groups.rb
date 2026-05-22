class CreateTournamentGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_groups do |t|
      t.integer :tournament_event_id, null: false
      t.string  :name, null: false

      t.timestamps
    end

    add_index :tournament_groups, :tournament_event_id
  end
end
