require "test_helper"

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    test "anonymous redirected to sign-in" do
      get admin_root_path
      assert_redirected_to new_session_path
    end

    test "regular user blocked" do
      sign_in_as(users(:one))
      get admin_root_path
      assert_redirected_to root_path
      assert_match "관리자 권한", flash[:alert].to_s
    end

    test "admin sees dashboard" do
      sign_in_as(users(:admin))
      get admin_root_path
      assert_response :success
      assert_select "h1", text: /Admin/
    end

    test "admin sees pending deck addition requests" do
      request_user = users(:one)
      DeckAdditionRequest.create!(
        user: request_user,
        requested_limit: Deck::PERSONAL_DECK_LIMIT + 1
      )

      sign_in_as(users(:admin))
      get admin_root_path

      assert_response :success
      assert_select "h2", text: "덱 추가 승인요청"
      assert_select "form[action=?]", admin_deck_addition_request_path(DeckAdditionRequest.last)
    end
  end
end
