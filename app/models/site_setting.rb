class SiteSetting < ApplicationRecord
  DEFAULT_KEY = "default"

  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :deck_community_open_chat_url, with: ->(url) { url.strip.presence }

  validates :key, presence: true, uniqueness: true
  validate :deck_community_open_chat_url_is_web_url

  def self.current
    find_or_create_by!(key: DEFAULT_KEY)
  end

  private

  def deck_community_open_chat_url_is_web_url
    return if deck_community_open_chat_url.blank?

    uri = URI.parse(deck_community_open_chat_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:deck_community_open_chat_url, "은(는) http 또는 https 주소여야 합니다")
  rescue URI::InvalidURIError
    errors.add(:deck_community_open_chat_url, "은(는) http 또는 https 주소여야 합니다")
  end
end
