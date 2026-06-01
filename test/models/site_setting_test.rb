require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "current returns a singleton settings record" do
    assert_difference -> { SiteSetting.count }, 1 do
      assert SiteSetting.current.persisted?
    end

    assert_equal SiteSetting.current, SiteSetting.current
  end

  test "deck community open chat url must be http or https" do
    setting = SiteSetting.new(deck_community_open_chat_url: "javascript:alert(1)")

    assert_not setting.valid?
    assert_includes setting.errors[:deck_community_open_chat_url], "은(는) http 또는 https 주소여야 합니다"
  end
end
