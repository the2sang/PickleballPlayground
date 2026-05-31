FactoryBot.define do
  factory :user_card_rating do
    association :user
    association :card
    difficulty { 3 }
  end
end
