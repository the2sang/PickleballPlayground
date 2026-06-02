class CreateCardBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :card_bookmarks do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :card, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :card_bookmarks, %i[user_id card_id], unique: true
  end
end
