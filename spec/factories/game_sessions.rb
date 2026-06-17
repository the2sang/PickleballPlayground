FactoryBot.define do
  factory :game_session do
    association :club
    title { "오픈 게임 #{Faker::Number.unique.number(digits: 4)}" }
    venue_name { "체육관 #{Faker::Address.building_number}" }
    address { Faker::Address.full_address }
    scheduled_date { Date.current + 1 }
    start_time { Time.zone.parse("19:00") }
    end_time { Time.zone.parse("21:00") }
    court_count { 1 }
    fee { 0 }
    max_participants { 8 }
    status { :open }
    visibility { :public_visibility }
    repeat_type { :no_repeat }

    trait :open_game do
      session_type { :open_game }
    end

    trait :with_court do
      court_name { "A코트" }
    end

    trait :closed do
      status { :closed }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :members_only do
      visibility { :members_only }
    end

    # 정원을 모두 채워 full? == true 로 만든다
    trait :full do
      transient do
        capacity { 8 }
      end
      max_participants { capacity }

      after(:create) do |session, evaluator|
        create_list(:participation, evaluator.capacity, :profile_complete_user,
                    game_session: session, status: :confirmed)
      end
    end
  end
end
