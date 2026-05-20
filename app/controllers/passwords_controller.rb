class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "잠시 후 다시 시도해 주세요." }

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address])

    if user.nil?
      redirect_to new_password_path(email_address: params[:email_address]),
                  alert: "가입되지 않은 이메일 주소입니다. 다시 확인해 주세요."
      return
    end

    PasswordsMailer.reset(user).deliver_now
    redirect_to new_session_path,
                notice: "#{user.email_address} 주소로 비밀번호 재설정 메일을 발송했습니다. 이메일을 확인해 주세요."
  rescue => e
    redirect_to new_password_path(email_address: params[:email_address]),
                alert: "메일 발송 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "비밀번호가 성공적으로 변경되었습니다. 새 비밀번호로 로그인해 주세요."
    else
      redirect_to edit_password_path(params[:token]), alert: "비밀번호가 일치하지 않습니다. 다시 입력해 주세요."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "비밀번호 재설정 링크가 유효하지 않거나 만료되었습니다. 다시 요청해 주세요."
    end
end
