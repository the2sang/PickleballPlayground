class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :deck,      null: false, foreign_key: { on_delete: :cascade }
      t.text       :front,     null: false
      t.text       :back,      null: false
      t.text       :hint
      t.string     :tags
      t.integer    :card_type, null: false, default: 0   # 0 = basic
      t.integer    :position,  null: false, default: 0
      t.timestamps
    end

    add_index :cards, [ :deck_id, :position ]
  end
end
