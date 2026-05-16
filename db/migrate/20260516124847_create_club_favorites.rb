class CreateClubFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :club_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :club, null: false, foreign_key: true

      t.timestamps
    end
    add_index :club_favorites, [:user_id, :club_id], unique: true
  end
end
