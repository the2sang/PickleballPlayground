class CreateDeckAdditionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :deck_addition_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :requested_limit, null: false
      t.datetime :approved_at
      t.integer :approved_by_id

      t.timestamps
    end

    add_index :deck_addition_requests, :status
    add_index :deck_addition_requests, :approved_by_id
  end
end
