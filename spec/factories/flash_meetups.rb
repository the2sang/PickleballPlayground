FactoryBot.define do
  factory :flash_meetup do
    association :user
    venue_name { "용인 실내 코트" }
    address    { "경기도 용인시" }
    start_date { 2.days.from_now.to_date }
    end_date   { 2.days.from_now.to_date }
    start_time { "10:00" }
    end_time   { "12:00" }
    max_participants { nil }
    gender_filter { :all_genders }
    level_filter  { :all_levels }
    allowed_age_groups { "" }
    kakao_open_chat_url { nil }

    trait :with_max do
      max_participants { 8 }
    end

    trait :full do
      max_participants { 1 }
      after(:create) do |fm|
        create(:flash_meetup_participation, flash_meetup: fm, status: :confirmed)
      end
    end

    trait :male_only do
      gender_filter { :male_only }
    end

    trait :advanced_only do
      level_filter { :advanced_only }
    end

    trait :age_restricted do
      allowed_age_groups { "thirties,forties" }
    end
  end
end
