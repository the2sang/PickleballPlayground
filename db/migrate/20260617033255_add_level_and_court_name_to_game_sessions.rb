class AddLevelAndCourtNameToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :level, :integer, null: false, default: 0
    add_column :game_sessions, :court_name, :string
  end
end
