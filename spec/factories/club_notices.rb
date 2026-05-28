FactoryBot.define do
  factory :club_notice do
    association :club
    sequence(:title) { |n| "공지사항 #{n}" }
    body { "클럽 공지 내용입니다." }
    published_at { Time.current }
  end
end
