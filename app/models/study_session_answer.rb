class StudySessionAnswer < ApplicationRecord
  belongs_to :study_session
  belongs_to :card

  validates :card_id, uniqueness: { scope: :study_session_id }
end
