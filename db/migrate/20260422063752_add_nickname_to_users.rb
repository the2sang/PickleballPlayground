class AddNicknameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nickname, :string

    execute("UPDATE users SET nickname = substr(email_address, 1, instr(email_address, '@') - 1) WHERE nickname IS NULL")

    change_column_null :users, :nickname, false
    add_index :users, :nickname, unique: true
  end
end
