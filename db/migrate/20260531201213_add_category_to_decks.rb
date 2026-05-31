class AddCategoryToDecks < ActiveRecord::Migration[8.1]
  def change
    add_column :decks, :category, :integer, null: false, default: 6
    add_index :decks, :category

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE decks
          SET category = CASE title
            WHEN '주식투자 기초 용어 30선' THEN 1
            WHEN '직장인이 알아야 할 경제 시사 상식 20선' THEN 1
            WHEN '개발자가 알아야 할 AI 기술 용어 30선' THEN 3
            WHEN '개발자가 알아야 할 AI 활용 용어 30선' THEN 3
            WHEN '피클볼 기본 룰 30선' THEN 4
            WHEN '스코어링 시나리오 20' THEN 4
            WHEN '영어 콜아웃 & 용어' THEN 5
            ELSE category
          END
        SQL
      end
    end
  end
end
