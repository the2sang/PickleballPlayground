class CreateMemberRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :member_records do |t|
      t.string :name, null: false
      t.string :club_name
      t.string :gender
      t.date :birth_date
      t.string :phone
      t.date :pickleball_started_at
      t.date :club_joined_at
      t.string :address
      t.boolean :privacy_agreed, null: false, default: false

      t.timestamps
    end
    add_index :member_records, :club_name
    add_index :member_records, :name
  end
end
