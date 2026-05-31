class DeckAdditionRequest < ApplicationRecord
  belongs_to :user
  belongs_to :approved_by, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1 }, default: :pending

  validates :requested_limit,
            presence: true,
            numericality: { only_integer: true, greater_than: Deck::PERSONAL_DECK_LIMIT }
  validates :user_id, uniqueness: { conditions: -> { pending }, message: "이미 처리 대기 중인 덱 추가 승인요청이 있습니다" },
                      if: :pending?

  scope :recent_first, -> { order(created_at: :desc) }

  def approve!(admin)
    update!(status: :approved, approved_by: admin, approved_at: Time.current)
  end
end
