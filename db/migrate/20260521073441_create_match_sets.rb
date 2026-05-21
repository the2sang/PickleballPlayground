class CreateMatchSets < ActiveRecord::Migration[8.1]
  def change
    create_table :match_sets do |t|
      t.integer :match_id, null: false
      t.integer :set_number, null: false
      t.integer :home_score, default: 0, null: false
      t.integer :away_score, default: 0, null: false

      t.timestamps
    end

    add_index :match_sets, :match_id
    add_index :match_sets, [ :match_id, :set_number ], unique: true
  end
end
