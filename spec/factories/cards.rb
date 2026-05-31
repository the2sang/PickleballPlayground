FactoryBot.define do
  factory :card do
    association :deck
    sequence(:front) { |n| "앞면 #{n}" }
    sequence(:back)  { |n| "뒷면 #{n}" }
    hint             { nil }
    tags             { "기본" }
    card_type        { :basic }
    sequence(:position) { |n| n }

    trait :multiple_choice do
      card_type { :multiple_choice }
      answer_choices { [ "오답 1", "오답 2", "오답 3" ] }
    end
  end
end
