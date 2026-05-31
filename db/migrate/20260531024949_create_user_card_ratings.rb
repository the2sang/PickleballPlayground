class CreateUserCardRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :user_card_ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :difficulty, null: false

      t.timestamps
    end

    add_index :user_card_ratings, [ :user_id, :card_id ], unique: true
  end
end
