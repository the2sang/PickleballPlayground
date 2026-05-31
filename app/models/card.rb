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

  has_one_attached :front_image
  has_one_attached :back_image

  enum :card_type, { basic: 0 }, default: :basic

  validates :front, presence: true, length: { maximum: 2000 }
  validates :back,  presence: true, length: { maximum: 2000 }
  validates :hint,  length: { maximum: 500 }, allow_blank: true
  validates :tags,  length: { maximum: 500 }, allow_blank: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :front_image_format
  validate :back_image_format

  scope :ordered, -> { order(:position, :id) }

  def quiz_options(deck, size: 3)
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
end
