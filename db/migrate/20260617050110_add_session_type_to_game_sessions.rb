class AddSessionTypeToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :session_type, :integer, null: false, default: 0
    add_index :game_sessions, [ :club_id, :session_type ]
  end
end
