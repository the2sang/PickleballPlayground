class AddUniqueIndexToGameSessionsTemplateDate < ActiveRecord::Migration[8.1]
  def change
    add_index :game_sessions, [ :template_id, :scheduled_date ],
              unique: true,
              where: "template_id IS NOT NULL",
              name: "index_game_sessions_on_template_and_date"
  end
end
