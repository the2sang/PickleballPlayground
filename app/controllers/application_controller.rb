class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  allow_browser versions: :modern

  stale_when_importmap_changes

  before_action :set_no_store_for_authenticated_pages

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_no_store_for_authenticated_pages
    response.headers["Cache-Control"] = "no-store" if authenticated?
  end

  def user_not_authorized
    flash[:alert] = "접근 권한이 없습니다."
    redirect_back_or_to(root_path)
  end
end
