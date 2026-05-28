FactoryBot.define do
  factory :tournament_event_deck do
    association :tournament_event
    association :deck, factory: [ :deck, :official ]
    sequence(:position) { |n| n }
  end
end
