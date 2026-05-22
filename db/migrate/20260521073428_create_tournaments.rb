class CreateTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :tournaments do |t|
      t.integer :club_id, null: false
      t.string  :name, null: false
      t.text    :description
      t.date    :starts_on
      t.date    :ends_on
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :tournaments, :club_id
    add_index :tournaments, :status
  end
end
