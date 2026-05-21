FactoryBot.define do
  factory :user do
    email_address { Faker::Internet.unique.email }
    password { "password" }
    nickname { Faker::Internet.unique.username(specifier: 4..12) }
    display_name { Faker::Name.name }
    sport_level { :beginner }
    age_group { :twenties }
    gender { :unspecified }
    role { :user }
    profile_completed_at { nil }

    trait :profile_complete do
      profile_completed_at { Time.current }
    end

    trait :admin do
      role { :admin }
      profile_completed_at { Time.current }
    end

    trait :male do
      gender { :male }
    end

    trait :female do
      gender { :female }
    end

    trait :intermediate do
      sport_level { :intermediate }
    end

    trait :advanced do
      sport_level { :advanced }
    end

    trait :thirties do
      age_group { :thirties }
    end

    trait :forties do
      age_group { :forties }
    end
  end
end
