require "test_helper"

module Admin
  class SiteSettingsControllerTest < ActionDispatch::IntegrationTest
    test "admin updates deck community open chat url" do
      admin = users(:admin)
      sign_in_as(admin)

      patch admin_site_setting_path, params: {
        site_setting: {
          deck_community_open_chat_url: "https://open.kakao.com/o/pickleball"
        }
      }

      assert_redirected_to admin_root_path(anchor: "deck-community")
      setting = SiteSetting.current
      assert_equal "https://open.kakao.com/o/pickleball", setting.deck_community_open_chat_url
      assert_equal admin, setting.updated_by
    end

    test "regular user cannot update site settings" do
      sign_in_as(users(:one))

      patch admin_site_setting_path, params: {
        site_setting: { deck_community_open_chat_url: "https://open.kakao.com/o/nope" }
      }

      assert_redirected_to root_path
      assert_nil SiteSetting.current.deck_community_open_chat_url
    end
  end
end
