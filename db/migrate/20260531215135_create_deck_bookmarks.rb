class CreateDeckBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :deck_bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :deck, null: false, foreign_key: true

      t.timestamps
    end

    add_index :deck_bookmarks, [ :user_id, :deck_id ], unique: true
  end
end
