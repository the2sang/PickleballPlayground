class AddContactKakaoToClubs < ActiveRecord::Migration[8.1]
  def change
    add_column :clubs, :contact_kakao, :string
  end
end
