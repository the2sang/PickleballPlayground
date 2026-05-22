class CreateFlashMeetups < ActiveRecord::Migration[8.1]
  def change
    create_table :flash_meetups do |t|
      t.references :user, null: false, foreign_key: true
      t.string :venue_name, null: false
      t.string :address
      t.datetime :scheduled_at, null: false
      t.integer :max_participants
      t.integer :gender_filter, null: false, default: 0
      t.integer :level_filter, null: false, default: 0
      t.string :allowed_age_groups, null: false, default: ""
      t.string :kakao_open_chat_url

      t.timestamps
    end
    add_index :flash_meetups, :scheduled_at
  end
end
