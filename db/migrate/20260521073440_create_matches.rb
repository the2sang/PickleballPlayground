class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.string  :matchable_type, null: false
      t.integer :matchable_id, null: false
      t.integer :home_team_id
      t.integer :away_team_id
      t.integer :winner_id
      t.integer :next_match_id
      t.integer :round, default: 0, null: false
      t.integer :match_number, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :matches, [ :matchable_type, :matchable_id ]
    add_index :matches, :home_team_id
    add_index :matches, :away_team_id
    add_index :matches, :next_match_id
    add_index :matches, :status
  end
end
