class AddWithdrawalReasonToClubMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :club_memberships, :withdrawal_reason, :string
  end
end
