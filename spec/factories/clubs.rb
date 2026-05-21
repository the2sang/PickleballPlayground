FactoryBot.define do
  factory :club do
    association :owner, factory: :user
    name { Faker::Team.unique.name }
    description { "테스트 클럽 설명" }
    status { :approved }
  end
end
