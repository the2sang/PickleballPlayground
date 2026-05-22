class AddCommentableAndParentToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :commentable_type, :string
    add_column :comments, :commentable_id,   :integer
    add_column :comments, :parent_id,        :integer

    add_index :comments, %i[commentable_type commentable_id]
    add_index :comments, :parent_id
  end
end
