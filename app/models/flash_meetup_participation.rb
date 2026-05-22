class FlashMeetupParticipation < ApplicationRecord
  belongs_to :flash_meetup
  belongs_to :user

  enum :status, { confirmed: 0, waitlisted: 1, cancelled: 2 }

  validates :status, presence: true
  validate :no_duplicate_active_participation, on: :create

  scope :active, -> { where.not(status: :cancelled) }

  def promote_from_waitlist!
    update!(status: :confirmed)
  end

  private

  def no_duplicate_active_participation
    return unless flash_meetup_id && user_id

    if FlashMeetupParticipation.where(flash_meetup_id:, user_id:).where.not(status: :cancelled).exists?
      errors.add(:base, "이미 신청한 모임입니다")
    end
  end
end
