class Deck < ApplicationRecord
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

  scope :featured, -> { where.not(featured_at: nil).order(featured_at: :desc) }

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
end
