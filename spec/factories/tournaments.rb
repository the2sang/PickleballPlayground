FactoryBot.define do
  factory :tournament do
    association :club
    name { "#{Faker::Sport.sport} 대회 #{Faker::Number.unique.number(digits: 3)}" }
    description { "대회 설명" }
    starts_on { Date.today + 7 }
    ends_on   { Date.today + 8 }
    status { :draft }
  end

  factory :tournament_event do
    association :tournament
    discipline { :mens_singles }
    advances_per_group { 2 }
    scoring_format { :single_game }
    points_to_win { 11 }
    status { :setup }
  end

  factory :tournament_team do
    association :tournament_event
    name { "팀 #{Faker::Name.last_name}" }
    seed { nil }
  end

  factory :tournament_team_member do
    association :tournament_team
    association :user
  end

  factory :tournament_group do
    association :tournament_event
    sequence(:name) { |n| "#{('A'.ord + (n - 1) % 26).chr}조" }
  end

  factory :tournament_group_team do
    association :tournament_group
    association :tournament_team
  end

  factory :match do
    association :matchable, factory: :tournament_group
    association :home_team, factory: :tournament_team
    association :away_team, factory: :tournament_team
    round { 0 }
    match_number { 1 }
    status { :pending }
  end

  factory :match_set do
    association :match
    set_number { 1 }
    home_score { 0 }
    away_score { 0 }
  end
end
