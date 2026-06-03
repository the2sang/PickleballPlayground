class SplitFlashMeetupScheduleFields < ActiveRecord::Migration[8.1]
  def up
    add_column :flash_meetups, :start_date, :date
    add_column :flash_meetups, :end_date, :date
    add_column :flash_meetups, :start_time, :time
    add_column :flash_meetups, :end_time, :time

    execute <<~SQL.squish
      UPDATE flash_meetups
         SET start_date = date(scheduled_at),
             end_date = date(COALESCE(ends_at, scheduled_at)),
             start_time = time(scheduled_at),
             end_time = CASE WHEN ends_at IS NOT NULL THEN time(ends_at) ELSE NULL END
    SQL

    change_column_null :flash_meetups, :start_date, false
    change_column_null :flash_meetups, :end_date, false
    add_index :flash_meetups, :start_date
  end

  def down
    remove_index :flash_meetups, :start_date
    remove_column :flash_meetups, :end_time
    remove_column :flash_meetups, :start_time
    remove_column :flash_meetups, :end_date
    remove_column :flash_meetups, :start_date
  end
end
