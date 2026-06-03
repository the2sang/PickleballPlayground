class AddHotZoneToClubs < ActiveRecord::Migration[8.1]
  def change
    add_column :clubs, :hot_zone, :boolean, null: false, default: false
  end
end
