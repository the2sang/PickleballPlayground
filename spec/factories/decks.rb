FactoryBot.define do
  factory :deck do
    sequence(:title) { |n| "테스트 덱 #{n}" }
    description      { "테스트 덱 설명" }
    scope            { :personal }
    association :owner, factory: :user

    trait :official do
      scope { :official }
      owner { nil }
    end

    trait :club do
      scope { :club }
      association :owner, factory: :club
    end

    trait :personal do
      scope { :personal }
      association :owner, factory: :user
    end

    trait :featured do
      featured_at { Time.current }
    end

    trait :forked do
      transient do
        source { create(:deck, :official) }
      end
      after(:build) do |deck, ev|
        deck.forked_from = ev.source
      end
    end
  end
end
