# Seeds — mirrors test fixtures so Railway production starts with usable demo data.
# Idempotent: safe to run multiple times via bin/rails db:seed.

puts "== Users =="

user_one = User.find_or_create_by!(email_address: "one@example.com") do |u|
  u.nickname    = "one_user"
  u.password    = "password"
  u.role        = :user
  u.sport_level = :beginner
  u.age_group   = :twenties
  u.gender      = :unspecified
end

user_two = User.find_or_create_by!(email_address: "two@example.com") do |u|
  u.nickname    = "two_user"
  u.password    = "password"
  u.role        = :user
  u.sport_level = :beginner
  u.age_group   = :twenties
  u.gender      = :unspecified
end

user_admin = User.find_or_create_by!(email_address: "admin@example.com") do |u|
  u.nickname    = "admin_user"
  u.password    = "password"
  u.role        = :admin
  u.sport_level = :beginner
  u.age_group   = :twenties
  u.gender      = :unspecified
end

User.find_or_create_by!(email_address: "three@example.com") do |u|
  u.nickname    = "three_user"
  u.password    = "password"
  u.role        = :user
  u.sport_level = :beginner
  u.age_group   = :twenties
  u.gender      = :unspecified
end

puts "   #{User.count} users"

puts "== Clubs =="

approved_club = Club.find_or_create_by!(name: "서울동호회") do |c|
  c.description = "서울 지역 동호회"
  c.owner       = user_one
  c.status      = :approved
end

Club.find_or_create_by!(name: "신규동호회") do |c|
  c.description = "승인 대기 중"
  c.owner       = user_one
  c.status      = :pending
end

puts "   #{Club.count} clubs"

puts "== Club Memberships =="

ClubMembership.find_or_create_by!(club: approved_club, user: user_two) do |m|
  m.role   = :manager
  m.status = :approved
end

ClubMembership.find_or_create_by!(club: approved_club, user: user_one) do |m|
  m.role   = :member
  m.status = :pending
end

puts "   #{ClubMembership.count} memberships"

puts "== Club Favorites =="

ClubFavorite.find_or_create_by!(club: approved_club, user: user_two)

puts "   #{ClubFavorite.count} favorites"

puts "== Game Sessions =="

open_session = GameSession.find_or_create_by!(club: approved_club, title: "토요 오픈 운동") do |s|
  s.venue_name       = "올림픽공원 코트 A"
  s.address          = "서울시 송파구 올림픽로 424"
  s.scheduled_date   = Date.new(2099, 12, 31)
  s.start_time       = "10:00"
  s.end_time         = "12:00"
  s.court_count      = 2
  s.fee              = 5000
  s.max_participants = 20
  s.visibility       = :public_visibility
  s.status           = :open
end

GameSession.find_or_create_by!(club: approved_club, title: "회원 전용 세션") do |s|
  s.venue_name     = "강남 실내코트"
  s.scheduled_date = Date.new(2099, 12, 31)
  s.start_time     = "14:00"
  s.end_time       = "16:00"
  s.court_count    = 1
  s.fee            = 0
  s.visibility     = :members_only
  s.status         = :open
end

puts "   #{GameSession.count} game sessions"

puts "== Participations =="

Participation.find_or_create_by!(game_session: open_session, user: user_admin) do |p|
  p.status = :confirmed
end

puts "   #{Participation.count} participations"

puts "== Flash Meetups =="

flash_one = FlashMeetup.find_or_create_by!(user: user_one, venue_name: "올림픽공원 코트 A") do |f|
  f.address            = "서울시 송파구 올림픽로 424"
  f.scheduled_at       = Time.zone.parse("2099-12-31 10:00:00")
  f.ends_at            = Time.zone.parse("2099-12-31 12:00:00")
  f.max_participants   = 10
  f.gender_filter      = :all_genders
  f.level_filter       = :all_levels
  f.allowed_age_groups = "[]"
end

FlashMeetup.find_or_create_by!(user: user_two, venue_name: "강남 실내코트") do |f|
  f.scheduled_at       = Time.zone.parse("2099-12-31 14:00:00")
  f.ends_at            = Time.zone.parse("2099-12-31 16:00:00")
  f.max_participants   = 8
  f.gender_filter      = :all_genders
  f.level_filter       = :all_levels
  f.allowed_age_groups = "[]"
end

puts "   #{FlashMeetup.count} flash meetups"

puts "== Flash Meetup Participations =="

FlashMeetupParticipation.find_or_create_by!(flash_meetup: flash_one, user: user_one) do |p|
  p.status = :confirmed
end

FlashMeetupParticipation.find_or_create_by!(flash_meetup: flash_one, user: user_two) do |p|
  p.status = :waitlisted
end

puts "   #{FlashMeetupParticipation.count} flash meetup participations"

puts "== Posts =="

Post.find_or_create_by!(title: "첫 번째 게시글", user: user_one)
Post.find_or_create_by!(title: "두 번째 게시글", user: user_one)

puts "   #{Post.count} posts"

puts "== Comments =="

Comment.find_or_create_by!(body: "첫 번째 댓글", user: user_one)
Comment.find_or_create_by!(body: "두 번째 댓글", user: user_two)

puts "   #{Comment.count} comments"

puts "== Work Journals =="

WorkJournal.find_or_create_by!(user: user_one, title: "오늘 한 일", work_date: Date.today) do |j|
  j.content         = "## 진행\n- 인증 모듈 완료"
  j.content_format  = "markdown"
  j.category        = :task
  j.status          = :in_progress
  j.progress        = 50
  j.is_draft        = false
  j.entry_type      = :result
  j.sequence_number = 1
end

WorkJournal.find_or_create_by!(user: user_one, title: "어제 회의", work_date: Date.yesterday) do |j|
  j.content         = "팀 미팅 정리"
  j.content_format  = "markdown"
  j.category        = :meeting
  j.status          = :completed
  j.progress        = 100
  j.is_draft        = false
  j.entry_type      = :result
  j.sequence_number = 1
end

WorkJournal.find_or_create_by!(user: user_two, title: "다른 사용자 일지", work_date: Date.today) do |j|
  j.content         = "권한 테스트용"
  j.content_format  = "markdown"
  j.category        = :task
  j.status          = :in_progress
  j.progress        = 0
  j.is_draft        = false
  j.entry_type      = :result
  j.sequence_number = 1
end

puts "   #{WorkJournal.count} work journals"

puts "== Site Admin =="

site_admin_email    = ENV["SITE_ADMIN_EMAIL"]
site_admin_password = ENV["SITE_ADMIN_PASSWORD"]
site_admin_nickname = ENV.fetch("SITE_ADMIN_NICKNAME", "관리자")

if site_admin_email.present? && site_admin_password.present?
  admin = User.find_or_initialize_by(email_address: site_admin_email)
  admin.nickname    = site_admin_nickname unless admin.persisted?
  admin.password    = site_admin_password unless admin.persisted?
  admin.role        = :admin
  admin.sport_level ||= :beginner
  admin.age_group   ||= :twenties
  admin.gender      ||= :unspecified
  admin.save!
  puts "   사이트 관리자 등록: #{site_admin_email}"
else
  puts "   SITE_ADMIN_EMAIL / SITE_ADMIN_PASSWORD 환경변수 없음 — 건너뜀"
end

puts "== Done =="
