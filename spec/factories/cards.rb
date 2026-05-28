FactoryBot.define do
  factory :card do
    association :deck
    sequence(:front) { |n| "앞면 #{n}" }
    sequence(:back)  { |n| "뒷면 #{n}" }
    hint             { nil }
    tags             { "기본" }
    card_type        { :basic }
    sequence(:position) { |n| n }
  end
end
