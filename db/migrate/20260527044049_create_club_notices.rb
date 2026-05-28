class CreateClubNotices < ActiveRecord::Migration[8.1]
  def change
    create_table :club_notices do |t|
      t.references :club, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :published_at

      t.timestamps
    end

    add_index :club_notices, [ :club_id, :created_at ]
  end
end
