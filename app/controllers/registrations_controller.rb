class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    @user = User.new
    @return_to = params[:return_to]
  end

  def create
    @user = User.new(registration_params)
    @return_to = params[:return_to]

    if @user.save
      Clubs::AssignManagerByEmailService.call(user: @user)
      start_new_session_for @user
      destination = case
      when @return_to == "new_club"
                      new_club_path
      when @return_to&.start_with?("/")
                      edit_profile_path(redirect_after: @return_to)
      else
                      root_path
      end
      redirect_to destination, notice: "가입을 환영합니다! 기본 정보를 입력해 주세요."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :nickname, :password, :password_confirmation)
  end
end
