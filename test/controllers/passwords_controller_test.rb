require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ] do
      post passwords_path, params: { email_address: @user.email_address }
    end
    assert_redirected_to new_session_path
  end

  test "create for an unknown user redirects to passwords form with alert" do
    assert_enqueued_emails 0 do
      post passwords_path, params: { email_address: "missing-user@example.com" }
    end
    assert_redirected_to new_password_path(email_address: "missing-user@example.com")
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "비밀번호 재설정 링크가 유효하지 않거나"
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "newpassword", password_confirmation: "newpassword" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "비밀번호가 성공적으로 변경되었습니다"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "비밀번호가 일치하지 않습니다"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
