class AddBankAccountToClubs < ActiveRecord::Migration[8.1]
  def change
    add_column :clubs, :bank_account, :string
  end
end
