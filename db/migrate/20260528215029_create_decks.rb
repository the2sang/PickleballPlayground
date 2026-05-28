class CreateDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :decks do |t|
      t.string   :title,              null: false
      t.text     :description
      t.integer  :scope,              null: false, default: 2   # 2 = personal
      t.string   :owner_type
      t.integer  :owner_id
      t.integer  :forked_from_deck_id
      t.datetime :featured_at
      t.timestamps
    end

    add_index :decks, [ :owner_type, :owner_id ]
    add_index :decks, :scope
    add_index :decks, :forked_from_deck_id
    add_index :decks, [ :scope, :featured_at ]

    add_foreign_key :decks, :decks, column: :forked_from_deck_id, on_delete: :nullify
  end
end
