class StudySession < ApplicationRecord
  belongs_to :user
  belongs_to :deck
  has_many :study_session_answers, dependent: :destroy

  scope :completed, -> { where.not(completed_at: nil) }

  def complete!(total:, correct:)
    update!(completed_at: Time.current, total_count: total, correct_count: correct)
  end

  def score_pct
    return nil if total_count.zero?
    (correct_count.to_f / total_count * 100).round
  end
end
