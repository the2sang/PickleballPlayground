class DropTechInfosAndLifeInfos < ActiveRecord::Migration[8.1]
  def up
    # Remove FK referencing tech_infos before dropping the parent table
    remove_column :comments, :tech_info_id if column_exists?(:comments, :tech_info_id)
    drop_table :tech_info_reactions, if_exists: true
    drop_table :tech_infos,          if_exists: true
    drop_table :life_infos,          if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
