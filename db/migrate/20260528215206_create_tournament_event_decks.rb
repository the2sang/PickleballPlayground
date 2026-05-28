class CreateTournamentEventDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_event_decks do |t|
      t.references :tournament_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :deck,             null: false, foreign_key: { on_delete: :cascade }
      t.integer    :position,         null: false, default: 0
      t.timestamps
    end

    add_index :tournament_event_decks, [ :tournament_event_id, :deck_id ], unique: true,
              name: "index_ted_on_event_and_deck"
    add_index :tournament_event_decks, [ :tournament_event_id, :position ],
              name: "index_ted_on_event_and_position"
  end
end
