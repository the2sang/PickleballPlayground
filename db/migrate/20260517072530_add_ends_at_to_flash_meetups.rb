class AddEndsAtToFlashMeetups < ActiveRecord::Migration[8.1]
  def change
    add_column :flash_meetups, :ends_at, :datetime
  end
end
