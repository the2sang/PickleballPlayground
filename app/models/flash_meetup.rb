class FlashMeetup < ApplicationRecord
  belongs_to :user
  has_many :flash_meetup_participations, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :participants, through: :flash_meetup_participations, source: :user

  enum :gender_filter, { all_genders: 0, male_only: 1, female_only: 2 }, prefix: :gender
  enum :level_filter, { all_levels: 0, intermediate_plus: 1, advanced_only: 2 }, prefix: :level

  # User#age_group enum keys
  ALLOWED_AGE_GROUPS = %w[twenties thirties forties fifties sixties_plus].freeze

  validates :venue_name, presence: true
  validates :scheduled_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_scheduled_at
  validates :gender_filter, presence: true
  validates :level_filter, presence: true
  validates :max_participants, numericality: { greater_than: 0, allow_nil: true }
  validates :kakao_open_chat_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "올바른 URL 형식이 아닙니다" },
            allow_blank: true

  scope :upcoming, -> { where("scheduled_at >= ?", Time.current).order(:scheduled_at) }
  scope :with_organizer, -> { includes(:user) }

  def allowed_age_group_list
    return [] if allowed_age_groups.blank?

    allowed_age_groups.split(",")
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

  def ends_at_after_scheduled_at
    return if ends_at.blank? || scheduled_at.blank?
    errors.add(:ends_at, "은 시작 시간 이후여야 합니다") if ends_at <= scheduled_at
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
