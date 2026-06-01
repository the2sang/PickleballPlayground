class User < ApplicationRecord
  CODE_DASH_KEY_LENGTH = 6
  CODE_DASH_ALPHABET = ("A".."Z").to_a.freeze

  has_secure_password validations: false
  generates_token_for :password_reset, expires_in: 1.hour do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :memos, dependent: :destroy
  has_many :work_plans,       dependent: :destroy
  has_many :work_journals,    dependent: :destroy
  has_many :manpower_records, dependent: :destroy
  has_one  :pomodoro_setting, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :owned_groups, class_name: "Group", foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner
  has_many :club_memberships, dependent: :destroy
  has_many :clubs_as_member, through: :club_memberships, source: :club
  has_many :club_favorites, dependent: :destroy
  has_many :favorited_clubs, through: :club_favorites, source: :club
  has_many :participations, dependent: :destroy
  has_many :flash_meetups, dependent: :destroy
  has_many :flash_meetup_participations, dependent: :destroy
  has_many :decks, as: :owner, dependent: :destroy
  has_many :card_reviews, dependent: :destroy
  has_many :study_sessions, dependent: :destroy
  has_many :user_card_ratings, dependent: :destroy
  has_many :deck_addition_requests, dependent: :destroy
  has_many :deck_bookmarks, dependent: :destroy
  has_many :updated_site_settings, class_name: "SiteSetting", foreign_key: :updated_by_id, dependent: :nullify, inverse_of: :updated_by

  def group_member_ids
    group_ids = group_memberships.select(:group_id)
    GroupMembership.where(group_id: group_ids).select(:user_id)
  end

  def group_members
    User.where(id: group_member_ids).where.not(id: id)
  end

  enum :role,        { user: 0, admin: 1, club: 2 },                                                           default: :user
  enum :sport_level, { beginner: 0, beginner_intermediate: 1, intermediate: 2, intermediate_advanced: 3, advanced: 4 },     default: :beginner
  enum :age_group,   { twenties: 0, thirties: 1, forties: 2, fifties: 3, sixties_plus: 4, teens: 5 },                       default: :twenties
  enum :gender,      { unspecified: 0, male: 1, female: 2, other: 3 },                                                      default: :unspecified

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(n) { n.strip }
  normalizes :code_dash_key, with: ->(key) { normalize_code_dash_key(key) }

  before_validation :ensure_code_dash_key, on: :create

  validates :email_address, presence: true,
                            uniqueness: { case_sensitive: false },
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nickname, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 2, maximum: 30 }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :display_name, length: { maximum: 30 }, allow_blank: true
  validates :code_dash_key,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { is: CODE_DASH_KEY_LENGTH },
            format: { with: /\A[A-Z]{6}\z/ }

  def profile_complete?
    profile_completed_at.present?
  end

  def personal_deck_limit
    Deck::PERSONAL_DECK_LIMIT + deck_addition_requests.approved.count
  end

  def personal_deck_count
    decks.personal.count
  end

  def can_create_personal_decks?(count = 1)
    personal_deck_count + count <= personal_deck_limit
  end

  def pending_deck_addition_request
    deck_addition_requests.pending.recent_first.first
  end

  def regenerate_code_dash_key!
    update!(
      code_dash_key: self.class.generate_unique_code_dash_key,
      code_dash_key_issued_at: Time.current,
      code_dash_key_last_used_at: nil
    )
    code_dash_key
  end

  def self.find_by_code_dash_key(key)
    normalized_key = normalize_code_dash_key(key)
    return if normalized_key.length != CODE_DASH_KEY_LENGTH

    find_by(code_dash_key: normalized_key)
  end

  def self.generate_unique_code_dash_key
    loop do
      key = Array.new(CODE_DASH_KEY_LENGTH) { CODE_DASH_ALPHABET[SecureRandom.random_number(CODE_DASH_ALPHABET.length)] }.join
      return key unless exists?(code_dash_key: key)
    end
  end

  def self.normalize_code_dash_key(key)
    key.to_s.upcase.gsub(/[^A-Z]/, "")
  end

  def self.find_or_create_by_oauth(auth)
    identity = Identity.find_by(provider: auth.provider, uid: auth.uid)
    return identity.user if identity

    user = find_by(email_address: auth.info.email) ||
           create!(
             email_address: auth.info.email,
             nickname: generate_unique_nickname(auth.info.name || auth.info.email.split("@").first),
             password: nil
           )
    user.identities.create!(provider: auth.provider, uid: auth.uid)
    user
  rescue ActiveRecord::RecordNotUnique
    Identity.find_by(provider: auth.provider, uid: auth.uid)&.user
  end

  def self.generate_unique_nickname(base)
    base = base.split("@").first if base.include?("@")
    base = base.gsub(/[^a-zA-Z0-9가-힣_]/, "").first(28).presence || "user"
    return base unless exists?(nickname: base)
    (2..99).each { |n| return "#{base}#{n}" unless exists?(nickname: "#{base}#{n}") }
    "#{base}#{SecureRandom.hex(3)}"
  end

  private

  def ensure_code_dash_key
    self.code_dash_key = self.class.generate_unique_code_dash_key if code_dash_key.blank?
    self.code_dash_key_issued_at ||= Time.current
  end
end
