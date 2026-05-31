FactoryBot.define do
  factory :deck_addition_request do
    association :user
    status { :pending }
    requested_limit { Deck::PERSONAL_DECK_LIMIT + 1 }

    trait :approved do
      status { :approved }
      approved_at { Time.current }
      association :approved_by, factory: [ :user, :admin ]
    end
  end
end
