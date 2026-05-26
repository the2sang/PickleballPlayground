class AddSubCategoryToTournamentEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :tournament_events, :sub_category, :string
  end
end
