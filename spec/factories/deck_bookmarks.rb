FactoryBot.define do
  factory :deck_bookmark do
    association :user
    association :deck
  end
end
