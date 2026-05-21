FactoryBot.define do
  factory :club do
    association :owner, factory: :user
    name { Faker::Team.unique.name }
    description { "테스트 클럽 설명" }
    status { :approved }
  end

  factory :club_membership do
    association :club
    association :user
    role { :member }
    status { :approved }
  end
end
