class AddMaxWaitlistToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :max_waitlist, :integer
  end
end
