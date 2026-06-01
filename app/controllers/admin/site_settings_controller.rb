module Admin
  class SiteSettingsController < BaseController
    def update
      @site_setting = SiteSetting.current
      authorize [ :admin, @site_setting ]

      if @site_setting.update(site_setting_params.merge(updated_by: Current.user))
        redirect_to admin_root_path(anchor: "deck-community"), notice: "덱 커뮤니티 오픈 카톡방 URL을 저장했습니다."
      else
        redirect_to admin_root_path(anchor: "deck-community"), alert: @site_setting.errors.full_messages.to_sentence
      end
    end

    private

    def site_setting_params
      params.require(:site_setting).permit(:deck_community_open_chat_url)
    end
  end
end
