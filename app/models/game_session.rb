class GameSession < ApplicationRecord
  belongs_to :club
  has_many :participations, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :template, class_name: "GameSession", optional: true
  has_many :instances, class_name: "GameSession", foreign_key: :template_id, dependent: :nullify

  enum :visibility,   { public_visibility: 0, members_only: 1 }, default: :public_visibility
  enum :status,       { open: 0, closed: 1, cancelled: 2 }, default: :open
  enum :repeat_type,  { no_repeat: 0, daily: 1, weekly: 2, specific_days: 3 }, default: :no_repeat
  enum :level, {
    all_level: 0, beginner: 1, beginner_intermediate: 2,
    intermediate: 3, intermediate_advanced: 4, advanced: 5
  }, default: :all_level
  enum :session_type, { regular: 0, open_game: 1 }, default: :regular

  DAYS_KO = %w[일 월 화 수 목 금 토].freeze

  # 오픈 게임 한 세션(코트)의 최대 슬롯 수. 정원을 넘는 슬롯은 대기 자리로 표시된다.
  SLOT_LIMIT = 12

  LEVEL_LABELS = {
    "all_level" => "올레벨", "beginner" => "초급", "beginner_intermediate" => "초중급",
    "intermediate" => "중급", "intermediate_advanced" => "중상급", "advanced" => "상급"
  }.freeze

  scope :templates, -> { where(template_id: nil).where.not(repeat_type: :no_repeat) }

  validates :title, :venue_name, :scheduled_date, :start_time, :end_time, presence: true
  validates :fee,              numericality: { greater_than_or_equal_to: 0 }
  validates :court_count,      numericality: { greater_than: 0 }, allow_nil: true
  validates :max_participants,  numericality: { greater_than: 0 }, allow_nil: true
  validate :end_time_after_start_time
  validate :repeat_ends_on_not_before_scheduled_date

  def repeating? = !no_repeat?

  def repeat_days_array
    repeat_days.present? ? repeat_days.split(",").map(&:to_i) : []
  end

  def repeat_days_label
    case repeat_type
    when "daily"    then "매일"
    when "weekly"   then "매주 #{DAYS_KO[scheduled_date.wday]}요일"
    when "specific_days" then repeat_days_array.map { DAYS_KO[_1] }.join("/") + "요일"
    end
  end

  def should_run_today?(date = Date.current)
    return false if repeat_ends_on.present? && date > repeat_ends_on
    case repeat_type
    when "daily"         then true
    when "weekly"        then date.wday == scheduled_date.wday
    when "specific_days" then repeat_days_array.include?(date.wday)
    else false
    end
  end

  def level_label = LEVEL_LABELS.fetch(level, level)

  # 슬롯 상한(12)에서 정원을 뺀 대기 자리 수
  def waitlist_capacity
    return 0 if max_participants.nil?
    [ SLOT_LIMIT - max_participants, 0 ].max
  end

  def full?
    return false if max_participants.nil?
    confirmed_count >= max_participants
  end

  def confirmed_count
    participations.confirmed.count
  end

  def session_ended?
    scheduled_date < Date.current ||
      (scheduled_date == Date.current && end_time < Time.current)
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?
    errors.add(:end_time, "은 시작 시간 이후여야 합니다.") unless end_time > start_time
  end

  def repeat_ends_on_not_before_scheduled_date
    return unless repeat_ends_on.present? && scheduled_date.present?
    errors.add(:repeat_ends_on, "은 시작일 이후여야 합니다.") if repeat_ends_on < scheduled_date
  end
end
