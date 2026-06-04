class ChangePhoneToKakaoIdInGuestApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :guest_applications, :kakao_id, :string
    change_column_null :guest_applications, :phone, true
    change_column_default :guest_applications, :phone, from: nil, to: nil
  end
end
