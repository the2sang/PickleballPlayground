class StudySessionAnswer < ApplicationRecord
  belongs_to :study_session
  belongs_to :card

  validates :card_id, uniqueness: { scope: :study_session_id }
  validates :selected_answer, length: { maximum: 2000 }, allow_blank: true
end
