require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "edit shows the current user's Code Dash Key" do
    user = users(:one)
    sign_in_as(user)

    get edit_account_path

    assert_response :success
    assert_select "p", "퀵접속 코드(Code Dash Key)"
    assert_select "strong", user.code_dash_key
    assert_includes response.body, "이 코드로 자신이 가입한 클럽에 신속하게 접속 가능합니다."
  end
end
