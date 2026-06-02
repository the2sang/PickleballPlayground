class Card < ApplicationRecord
  # NOTE(phase-2): has_one_attached creates a :front_image= writer; strong_params in
  # CardsController MUST NOT permit :front_image or :back_image. The image upload UI
  # is permanently hidden in v1 — image attachments are deferred until S3/R2 is wired
  # (out of scope v1). See PITFALLS §"Image attachment param leak".

  MAX_IMAGE_BYTES     = 5.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze

  belongs_to :deck
  has_many :card_reviews, dependent: :destroy
  has_many :user_card_ratings, dependent: :destroy
  has_many :card_bookmarks, dependent: :destroy

  has_one_attached :front_image
  has_one_attached :back_image

  enum :card_type, { basic: 0, multiple_choice: 1 }, default: :basic

  validates :front, presence: true, length: { maximum: 2000 }
  validates :back,  presence: true, length: { maximum: 2000 }
  validates :hint,  length: { maximum: 500 }, allow_blank: true
  validates :tags,  length: { maximum: 500 }, allow_blank: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :front_image_format
  validate :back_image_format
  validate :multiple_choice_answer_choices
  validate :personal_deck_size_limit

  scope :ordered, -> { order(:position, :id) }

  def answer_choices
    JSON.parse(self[:answer_choices].presence || "[]")
  rescue JSON::ParserError
    []
  end

  def answer_choices=(values)
    self[:answer_choices] = Array(values).compact_blank.map(&:to_s).map(&:strip).uniq.to_json
  end

  def quiz_options(deck, size: 3)
    if multiple_choice? && answer_choices.present?
      return ([ back ] + answer_choices.first(size)).shuffle
    end

    distractors = deck.cards.where.not(id: id).order("RANDOM()").limit(size)
    ([ back ] + distractors.map(&:back)).shuffle
  end

  private

  def front_image_format = validate_image(:front_image)
  def back_image_format  = validate_image(:back_image)

  def validate_image(field)
    attached = public_send(field)
    return unless attached.attached?

    errors.add(field, "허용되지 않은 이미지 형식") unless ALLOWED_IMAGE_TYPES.include?(attached.blob.content_type)
    errors.add(field, "이미지가 너무 큽니다 (최대 5MB)")     if attached.blob.byte_size > MAX_IMAGE_BYTES
  end

  def multiple_choice_answer_choices
    return unless multiple_choice?

    errors.add(:answer_choices, "객관식 카드는 오답 선택지 3개가 필요합니다") if answer_choices.size < 3
  end

  def personal_deck_size_limit
    return unless deck&.personal_deck_size_limit_exceeded?(additional_cards: [ self ], excluded_card: self)

    errors.add(:base, "사용자 정의 덱 1개당 최대 크기는 #{Deck::PERSONAL_DECK_SIZE_LIMIT_BYTES / 1.megabyte}MB입니다.")
  end
end
