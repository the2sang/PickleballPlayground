FactoryBot.define do
  factory :flash_meetup_participation do
    association :flash_meetup
    association :user
    status { :confirmed }

    trait :waitlisted do
      status { :waitlisted }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
