class AddAdditionalInfoToFlashMeetups < ActiveRecord::Migration[8.1]
  def change
    add_column :flash_meetups, :additional_info, :text
  end
end
