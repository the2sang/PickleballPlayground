class CreateSloganVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :slogan_votes do |t|
      t.integer :slogan_number, null: false
      t.string :voter_name, null: false

      t.timestamps
    end

    add_index :slogan_votes, :slogan_number, unique: true
  end
end
