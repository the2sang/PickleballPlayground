FactoryBot.define do
  factory :study_session_answer do
    association :study_session
    association :card
    rating     { 4 }
    is_correct { true }

    trait :incorrect do
      rating     { 1 }
      is_correct { false }
    end
  end
end
