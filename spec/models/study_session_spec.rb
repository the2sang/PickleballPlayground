require 'rails_helper'

RSpec.describe StudySession, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:deck) }
    it { should have_many(:study_session_answers).dependent(:destroy) }
  end

  describe '.completed' do
    it 'includes sessions with completed_at set' do
      done    = create(:study_session, completed_at: 1.hour.ago, total_count: 5, correct_count: 4)
      incomplete_session = create(:study_session, completed_at: nil)
      expect(StudySession.completed).to include(done)
      expect(StudySession.completed).not_to include(incomplete_session)
    end
  end

  describe '#score_pct' do
    it 'returns nil when total_count is zero' do
      s = build(:study_session, total_count: 0, correct_count: 0)
      expect(s.score_pct).to be_nil
    end

    it 'returns rounded integer percentage' do
      s = build(:study_session, total_count: 10, correct_count: 8)
      expect(s.score_pct).to eq(80)
    end

    it 'rounds down correctly' do
      s = build(:study_session, total_count: 3, correct_count: 1)
      expect(s.score_pct).to eq(33)
    end
  end

  describe '#complete!' do
    it 'sets completed_at, total_count, correct_count' do
      session = create(:study_session)
      freeze_time do
        session.complete!(total: 10, correct: 7)
        expect(session.completed_at).to eq(Time.current)
        expect(session.total_count).to eq(10)
        expect(session.correct_count).to eq(7)
      end
    end
  end
end
