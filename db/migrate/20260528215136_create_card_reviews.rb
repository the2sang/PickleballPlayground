class CreateCardReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :card_reviews do |t|
      t.references :user,            null: false, foreign_key: { on_delete: :cascade }
      t.references :card,            null: false, foreign_key: { on_delete: :cascade }
      t.decimal    :ease,            precision: 4, scale: 2, null: false, default: 2.5
      t.integer    :interval_days,   null: false, default: 0
      t.integer    :repetitions,     null: false, default: 0
      t.datetime   :next_review_at
      t.datetime   :last_reviewed_at
      t.integer    :last_rating
      t.timestamps
    end

    add_index :card_reviews, [ :user_id, :card_id ], unique: true
    add_index :card_reviews, [ :user_id, :next_review_at ]   # critical due-queue index (ROADMAP + PITFALLS Perf Trap #1)
  end
end
