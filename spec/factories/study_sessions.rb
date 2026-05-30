FactoryBot.define do
  factory :study_session do
    association :user
    association :deck
    repeat        { false }
    completed_at  { nil }
    total_count   { 0 }
    correct_count { 0 }

    trait :completed do
      completed_at  { 1.hour.ago }
      total_count   { 10 }
      correct_count { 8 }
    end
  end
end
