class AccountsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if credential_params[:password].present?
      unless @user.authenticate(params[:user][:current_password].to_s)
        @user.errors.add(:base, "현재 비밀번호가 올바르지 않습니다.")
        render :edit, status: :unprocessable_entity and return
      end
    end

    if @user.update(account_params)
      redirect_to edit_account_path, notice: "계정 정보가 업데이트되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def credential_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def account_params
    permitted = params.require(:user).permit(:email_address, :nickname, :password, :password_confirmation)
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password].blank?
    permitted
  end
end
