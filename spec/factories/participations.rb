FactoryBot.define do
  factory :participation do
    association :game_session
    association :user
    status { :confirmed }
    participation_type { :as_member }

    trait :profile_complete_user do
      association :user, factory: %i[user profile_complete]
    end

    trait :waitlisted do
      status { :waitlisted }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :as_guest do
      participation_type { :as_guest }
    end
  end
end
