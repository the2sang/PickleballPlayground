class Deck < ApplicationRecord
  PERSONAL_DECK_LIMIT = 10
  PERSONAL_DECK_SIZE_LIMIT_BYTES = 1.megabyte

  belongs_to :owner, polymorphic: true, optional: true

  belongs_to :forked_from,
             class_name:  "Deck",
             foreign_key: :forked_from_deck_id,
             optional:    true,
             inverse_of:  :forks
  has_many :forks,
           class_name:  "Deck",
           foreign_key: :forked_from_deck_id,
           dependent:   :nullify,
           inverse_of:  :forked_from

  has_many :cards, -> { order(:position) }, dependent: :destroy
  has_many :tournament_event_decks, dependent: :destroy
  has_many :tournament_events, through: :tournament_event_decks

  enum :scope, { official: 0, club: 1, personal: 2 }, default: :personal

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validate  :owner_matches_scope
  validate  :personal_deck_count_within_owner_limit, on: :create
  validate  :personal_deck_size_within_limit

  scope :featured, -> { where.not(featured_at: nil).order(featured_at: :desc) }

  def self.content_size_bytes(title:, description:, cards: [])
    values = [ title, description ]
    Array(cards).each do |card|
      values.concat([ card[:front], card[:back], card[:hint], card[:tags], card[:answer_choices] ])
    end
    values.compact.sum { |value| value.to_s.bytesize }
  end

  def content_size_bytes(additional_cards: [], excluded_card: nil)
    existing_cards =
      if cards.loaded?
        cards.reject { |card| same_card?(card, excluded_card) }
      elsif excluded_card&.id
        cards.where.not(id: excluded_card.id).to_a
      else
        cards.to_a
      end

    self.class.content_size_bytes(
      title: title,
      description: description,
      cards: existing_cards + Array(additional_cards)
    )
  end

  def personal_deck_size_limit_exceeded?(additional_cards: [], excluded_card: nil)
    return false unless personal? && owner.is_a?(User)

    content_size_bytes(additional_cards: additional_cards, excluded_card: excluded_card) > PERSONAL_DECK_SIZE_LIMIT_BYTES
  end

  private

  def owner_matches_scope
    case scope&.to_sym
    when :official
      errors.add(:owner, "공식 덱은 소유자가 없어야 합니다") if owner.present?
    when :club
      errors.add(:owner, "클럽 덱은 Club을 owner로 가져야 합니다") unless owner.is_a?(Club)
    when :personal
      errors.add(:owner, "개인 덱은 User를 owner로 가져야 합니다") unless owner.is_a?(User)
    end
  end

  def personal_deck_count_within_owner_limit
    return unless personal? && owner.is_a?(User)
    return if owner.can_create_personal_decks?

    errors.add(:base, "사용자 정의 덱은 최대 #{owner.personal_deck_limit}개까지 추가할 수 있습니다. 덱 추가 승인요청 후 다시 시도해 주세요.")
  end

  def personal_deck_size_within_limit
    return unless personal_deck_size_limit_exceeded?

    errors.add(:base, "사용자 정의 덱 1개당 최대 크기는 #{PERSONAL_DECK_SIZE_LIMIT_BYTES / 1.megabyte}MB입니다.")
  end

  def same_card?(card, other)
    other && (card.equal?(other) || (card.id.present? && card.id == other.id))
  end
end
