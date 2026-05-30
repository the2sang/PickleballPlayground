class CreateStudySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :study_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :deck, null: false, foreign_key: { on_delete: :cascade }
      t.boolean  :repeat,        null: false, default: false
      t.datetime :completed_at
      t.integer  :total_count,   null: false, default: 0
      t.integer  :correct_count, null: false, default: 0
      t.timestamps
    end

    add_index :study_sessions, %i[user_id deck_id]
    add_index :study_sessions, %i[user_id completed_at]
  end
end
