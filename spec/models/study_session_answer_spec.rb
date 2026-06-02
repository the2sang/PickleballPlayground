require 'rails_helper'

RSpec.describe StudySessionAnswer, type: :model do
  describe 'associations' do
    it { should belong_to(:study_session) }
    it { should belong_to(:card) }
  end

  describe 'validations' do
    subject { build(:study_session_answer) }
    it { should validate_uniqueness_of(:card_id).scoped_to(:study_session_id) }
    it { should validate_length_of(:selected_answer).is_at_most(2000) }
  end
end
