require "securerandom"

class AddCodeDashKeyToUsers < ActiveRecord::Migration[8.1]
  CODE_DASH_ALPHABET = ("A".."Z").to_a.freeze
  CODE_DASH_KEY_LENGTH = 6

  def up
    add_column :users, :code_dash_key, :string
    add_column :users, :code_dash_key_issued_at, :datetime
    add_column :users, :code_dash_key_last_used_at, :datetime
    add_index :users, :code_dash_key, unique: true

    backfill_code_dash_keys
    change_column_null :users, :code_dash_key, false
  end

  def down
    remove_index :users, :code_dash_key
    remove_column :users, :code_dash_key_last_used_at
    remove_column :users, :code_dash_key_issued_at
    remove_column :users, :code_dash_key
  end

  private

  def backfill_code_dash_keys
    say_with_time "Backfilling user code dash keys" do
      suppress_messages do
        connection.select_values("SELECT id FROM users WHERE code_dash_key IS NULL").each do |user_id|
          key = unique_code_dash_key
          connection.execute <<~SQL.squish
            UPDATE users
            SET code_dash_key = #{connection.quote(key)},
                code_dash_key_issued_at = #{connection.quote(Time.current)}
            WHERE id = #{connection.quote(user_id)}
          SQL
        end
      end
    end
  end

  def unique_code_dash_key
    loop do
      key = Array.new(CODE_DASH_KEY_LENGTH) { CODE_DASH_ALPHABET[SecureRandom.random_number(CODE_DASH_ALPHABET.length)] }.join
      return key unless connection.select_value("SELECT 1 FROM users WHERE code_dash_key = #{connection.quote(key)} LIMIT 1")
    end
  end
end
