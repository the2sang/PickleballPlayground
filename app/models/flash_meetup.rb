class FlashMeetup < ApplicationRecord
  belongs_to :user
  has_many :flash_meetup_participations, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :participants, through: :flash_meetup_participations, source: :user

  enum :gender_filter, { all_genders: 0, male_only: 1, female_only: 2 }, prefix: :gender
  enum :level_filter, { all_levels: 0, intermediate_plus: 1, advanced_only: 2 }, prefix: :level

  # User#age_group enum keys
  ALLOWED_AGE_GROUPS = %w[twenties thirties forties fifties sixties_plus].freeze

  before_validation :sync_schedule_fields

  validates :venue_name, presence: true
  validates :start_date, :end_date, presence: true
  validates :scheduled_at, presence: true
  validate :end_schedule_not_before_start
  validates :gender_filter, presence: true
  validates :level_filter, presence: true
  validates :max_participants, numericality: { greater_than: 0, allow_nil: true }
  validates :kakao_open_chat_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "올바른 URL 형식이 아닙니다" },
            allow_blank: true

  scope :upcoming, -> { where("ends_at IS NULL OR ends_at >= ?", Time.current).order(:scheduled_at) }
  scope :with_organizer, -> { includes(:user) }

  def allowed_age_group_list
    return [] if allowed_age_groups.blank?

    allowed_age_groups.split(",")
  end

  def start_time?
    start_time.present?
  end

  def end_time?
    end_time.present?
  end

  def confirmed_count
    flash_meetup_participations.confirmed.count
  end

  def full?
    return false if max_participants.nil?

    confirmed_count >= max_participants
  end

  def eligible?(user)
    gender_eligible?(user) && level_eligible?(user) && age_eligible?(user)
  end

  private

  def sync_schedule_fields
    sync_split_fields_from_datetimes
    sync_datetimes_from_split_fields
  end

  def sync_split_fields_from_datetimes
    self.start_date ||= scheduled_at&.to_date
    self.start_time ||= scheduled_at if scheduled_at.present?
    self.end_date ||= ends_at&.to_date || start_date
    self.end_time ||= ends_at if ends_at.present?
  end

  def sync_datetimes_from_split_fields
    self.scheduled_at = combine_schedule_datetime(start_date, start_time, fallback: :beginning_of_day) if start_date.present?
    self.ends_at = combine_schedule_datetime(end_date, end_time, fallback: :end_of_day) if end_date.present?
  end

  def combine_schedule_datetime(date_value, time_value, fallback:)
    date = date_value.to_date
    return date.in_time_zone.public_send(fallback) if time_value.blank?

    Time.zone.local(date.year, date.month, date.day, time_value.hour, time_value.min, 0)
  end

  def end_schedule_not_before_start
    return if start_date.blank? || end_date.blank?

    if end_date < start_date
      errors.add(:end_date, "은 시작일 이후여야 합니다")
    elsif end_date == start_date && start_time.present? && end_time.present? && end_time <= start_time
      errors.add(:end_time, "은 시작시간 이후여야 합니다")
    end
  end

  def gender_eligible?(user)
    return true if gender_all_genders?

    gender_male_only? ? user.male? : user.female?
  end

  def level_eligible?(user)
    return true if level_all_levels?

    case level_filter
    when "intermediate_plus"
      user.intermediate? || user.intermediate_advanced? || user.advanced?
    when "advanced_only"
      user.advanced?
    else
      true
    end
  end

  def age_eligible?(user)
    return true if allowed_age_group_list.empty?

    allowed_age_group_list.include?(user.age_group)
  end
end
