class AddHotZoneToFlashMeetups < ActiveRecord::Migration[8.1]
  def change
    add_column :flash_meetups, :hot_zone, :boolean, null: false, default: false
  end
end
