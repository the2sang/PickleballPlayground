require "rails_helper"

RSpec.describe GameSession, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:club) }
    it { is_expected.to have_many(:participations).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:game_session) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:scheduled_date) }

    it "court_name 은 선택 사항이다" do
      expect(build(:game_session, court_name: nil)).to be_valid
    end
  end

  describe "level enum" do
    it "기본값은 all_level 이다" do
      expect(GameSession.new.level).to eq("all_level")
    end

    it "스펙에 정의된 6단계를 갖는다" do
      expect(GameSession.levels.keys).to eq(
        %w[all_level beginner beginner_intermediate intermediate intermediate_advanced advanced]
      )
    end

    it "레벨 한글 라벨을 반환한다" do
      expect(build(:game_session, level: :all_level).level_label).to eq("올레벨")
      expect(build(:game_session, level: :beginner).level_label).to eq("초급")
      expect(build(:game_session, level: :beginner_intermediate).level_label).to eq("초중급")
      expect(build(:game_session, level: :intermediate).level_label).to eq("중급")
      expect(build(:game_session, level: :intermediate_advanced).level_label).to eq("중상급")
      expect(build(:game_session, level: :advanced).level_label).to eq("상급")
    end
  end

  describe "session_type enum" do
    it "기본값은 regular(클럽 운동 세션) 이다" do
      expect(GameSession.new.session_type).to eq("regular")
    end

    it "open_game 으로 지정할 수 있다" do
      expect(build(:game_session, :open_game)).to be_open_game
    end
  end

  describe "#waitlist_capacity" do
    it "정원 8, 슬롯 상한 12 이면 대기 정원은 4 이다" do
      session = build(:game_session, max_participants: 8)
      expect(session.waitlist_capacity).to eq(4)
    end

    it "정원이 12 이상이면 대기 정원은 0 이다" do
      session = build(:game_session, max_participants: 12)
      expect(session.waitlist_capacity).to eq(0)
    end
  end

  describe "session time status" do
    around do |example|
      travel_to Time.zone.local(2026, 6, 20, 12, 0, 0) do
        example.run
      end
    end

    it "오늘 현재 시간 이후에 끝나는 세션은 종료로 보지 않는다" do
      session = build(:game_session,
                      scheduled_date: Date.current,
                      start_time: Time.zone.parse("19:00"),
                      end_time: Time.zone.parse("21:00"))

      expect(session).not_to be_session_started
      expect(session).not_to be_session_ended
    end

    it "오늘 진행 중인 세션은 시작됐지만 종료로 보지 않는다" do
      session = build(:game_session,
                      scheduled_date: Date.current,
                      start_time: Time.zone.parse("10:00"),
                      end_time: Time.zone.parse("13:00"))

      expect(session).to be_session_started
      expect(session).not_to be_session_ended
    end

    it "오늘 종료 시간이 지난 세션은 종료로 본다" do
      session = build(:game_session,
                      scheduled_date: Date.current,
                      start_time: Time.zone.parse("09:00"),
                      end_time: Time.zone.parse("11:00"))

      expect(session).to be_session_started
      expect(session).to be_session_ended
    end
  end
end
