class Club < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :club_memberships, dependent: :destroy
  has_many :members, through: :club_memberships, source: :user
  has_many :game_sessions, dependent: :destroy
  has_many :template_sessions,
           -> { where(template_id: nil) },
           class_name: "GameSession"
  has_many :guest_applications, dependent: :destroy
  has_many :club_favorites, dependent: :destroy
  has_many :tournaments, dependent: :destroy
  has_many :club_notices, dependent: :destroy

  enum :status, { pending: 0, approved: 1, suspended: 2 }, default: :pending

  normalizes :name,          with: ->(n) { n.strip }
  normalizes :contact_email, with: ->(e) { e.strip.downcase }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :owner, presence: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def operation_day_indices
    days = []
    template_sessions.each do |gs|
      case gs.repeat_type
      when "daily"         then return (0..6).to_a
      when "weekly"        then days << gs.scheduled_date.wday
      when "specific_days" then days.concat(gs.repeat_days_array)
      when "no_repeat"     then days << gs.scheduled_date.wday
      end
    end
    days.uniq.sort
  end
end
