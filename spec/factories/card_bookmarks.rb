FactoryBot.define do
  factory :card_bookmark do
    association :user
    association :card
  end
end
