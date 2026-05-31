class AddAnswerChoicesToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :answer_choices, :text
  end
end
