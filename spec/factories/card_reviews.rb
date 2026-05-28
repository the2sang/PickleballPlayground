FactoryBot.define do
  factory :card_review do
    association :user
    association :card
    ease             { 2.5 }
    interval_days    { 0 }
    repetitions      { 0 }
    next_review_at   { nil }
    last_reviewed_at { nil }
    last_rating      { nil }

    trait :due do
      next_review_at   { 1.hour.ago }
      last_reviewed_at { 1.day.ago }
      interval_days    { 1 }
      repetitions      { 1 }
      last_rating      { 3 }
    end

    trait :mature do
      ease             { 2.4 }
      interval_days    { 21 }
      repetitions      { 5 }
      next_review_at   { 5.days.from_now }
      last_reviewed_at { 16.days.ago }
      last_rating      { 3 }
    end
  end
end
