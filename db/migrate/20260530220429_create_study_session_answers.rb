class CreateStudySessionAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :study_session_answers do |t|
      t.references :study_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :card,          null: false, foreign_key: { on_delete: :cascade }
      t.integer  :rating,     null: false
      t.boolean  :is_correct, null: false
      t.timestamps
    end

    add_index :study_session_answers, %i[study_session_id card_id], unique: true
  end
end
