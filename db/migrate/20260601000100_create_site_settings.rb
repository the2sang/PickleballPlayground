class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.string :key, null: false, default: "default"
      t.string :deck_community_open_chat_url
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :site_settings, :key, unique: true
  end
end
