require "rails_helper"

RSpec.describe FlashMeetup, type: :model do
  subject { build(:flash_meetup) }

  # ── Associations ──────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:flash_meetup_participations).dependent(:destroy) }
    it { is_expected.to have_many(:participants).through(:flash_meetup_participations).source(:user) }
  end

  # ── Validations ───────────────────────────────────────────
  describe "validations" do
    it { is_expected.to validate_presence_of(:venue_name) }
    it { is_expected.to validate_presence_of(:scheduled_at) }
    it { is_expected.to validate_numericality_of(:max_participants).is_greater_than(0).allow_nil }

    context "kakao_open_chat_url" do
      it "accepts a valid https URL" do
        subject.kakao_open_chat_url = "https://open.kakao.com/o/abc123"
        expect(subject).to be_valid
      end

      it "accepts blank" do
        subject.kakao_open_chat_url = ""
        expect(subject).to be_valid
      end

      it "rejects a non-URL string" do
        subject.kakao_open_chat_url = "not-a-url"
        expect(subject).not_to be_valid
        expect(subject.errors[:kakao_open_chat_url]).to be_present
      end
    end
  end

  # ── #allowed_age_group_list ───────────────────────────────
  describe "#allowed_age_group_list" do
    it "returns empty array when blank" do
      subject.allowed_age_groups = ""
      expect(subject.allowed_age_group_list).to eq([])
    end

    it "splits comma-separated string" do
      subject.allowed_age_groups = "twenties,thirties"
      expect(subject.allowed_age_group_list).to eq(%w[twenties thirties])
    end
  end

  # ── #confirmed_count ─────────────────────────────────────
  describe "#confirmed_count" do
    let(:meetup) { create(:flash_meetup) }

    it "counts only confirmed participations" do
      create(:flash_meetup_participation, flash_meetup: meetup, status: :confirmed)
      create(:flash_meetup_participation, flash_meetup: meetup, status: :waitlisted)
      create(:flash_meetup_participation, flash_meetup: meetup, status: :cancelled)
      expect(meetup.confirmed_count).to eq(1)
    end
  end

  # ── #full? ───────────────────────────────────────────────
  describe "#full?" do
    context "when max_participants is nil" do
      it "returns false" do
        meetup = build(:flash_meetup, max_participants: nil)
        expect(meetup.full?).to be false
      end
    end

    context "when confirmed_count < max_participants" do
      it "returns false" do
        meetup = create(:flash_meetup, max_participants: 5)
        expect(meetup.full?).to be false
      end
    end

    context "when confirmed_count == max_participants" do
      it "returns true" do
        meetup = create(:flash_meetup, :full)
        expect(meetup.full?).to be true
      end
    end
  end

  # ── #eligible? ───────────────────────────────────────────
  describe "#eligible?" do
    let(:meetup) { build(:flash_meetup) }
    let(:user)   { build(:user, :profile_complete, gender: :male, sport_level: :intermediate, age_group: :thirties) }

    context "모든 필터가 무관(all_*)일 때" do
      it "항상 eligible" do
        expect(meetup.eligible?(user)).to be true
      end
    end

    context "성별 필터" do
      context "male_only" do
        let(:meetup) { build(:flash_meetup, gender_filter: :male_only) }

        it "남성 유저는 eligible" do
          expect(meetup.eligible?(user)).to be true
        end

        it "여성 유저는 ineligible" do
          female = build(:user, :profile_complete, gender: :female, sport_level: :intermediate, age_group: :thirties)
          expect(meetup.eligible?(female)).to be false
        end
      end

      context "female_only" do
        let(:meetup) { build(:flash_meetup, gender_filter: :female_only) }

        it "여성 유저는 eligible" do
          female = build(:user, :profile_complete, gender: :female, sport_level: :intermediate, age_group: :thirties)
          expect(meetup.eligible?(female)).to be true
        end

        it "남성 유저는 ineligible" do
          expect(meetup.eligible?(user)).to be false
        end
      end
    end

    context "실력 필터" do
      context "intermediate_plus" do
        let(:meetup) { build(:flash_meetup, level_filter: :intermediate_plus) }

        it "intermediate 유저는 eligible" do
          expect(meetup.eligible?(user)).to be true
        end

        it "advanced 유저는 eligible" do
          adv = build(:user, :profile_complete, gender: :male, sport_level: :advanced, age_group: :thirties)
          expect(meetup.eligible?(adv)).to be true
        end

        it "beginner 유저는 ineligible" do
          beg = build(:user, :profile_complete, gender: :male, sport_level: :beginner, age_group: :thirties)
          expect(meetup.eligible?(beg)).to be false
        end
      end

      context "advanced_only" do
        let(:meetup) { build(:flash_meetup, level_filter: :advanced_only) }

        it "advanced 유저는 eligible" do
          adv = build(:user, :profile_complete, gender: :male, sport_level: :advanced, age_group: :thirties)
          expect(meetup.eligible?(adv)).to be true
        end

        it "intermediate 유저는 ineligible" do
          expect(meetup.eligible?(user)).to be false
        end
      end
    end

    context "연령 필터" do
      let(:meetup) { build(:flash_meetup, allowed_age_groups: "thirties,forties") }

      it "thirties 유저는 eligible" do
        expect(meetup.eligible?(user)).to be true
      end

      it "twenties 유저는 ineligible" do
        young = build(:user, :profile_complete, gender: :male, sport_level: :intermediate, age_group: :twenties)
        expect(meetup.eligible?(young)).to be false
      end

      it "빈 allowed_age_groups이면 모든 연령 eligible" do
        meetup.allowed_age_groups = ""
        young = build(:user, :profile_complete, gender: :male, sport_level: :intermediate, age_group: :twenties)
        expect(meetup.eligible?(young)).to be true
      end
    end

    context "복합 필터 — 성별+실력+연령 모두 통과해야 eligible" do
      let(:meetup) do
        build(:flash_meetup,
              gender_filter: :male_only,
              level_filter: :intermediate_plus,
              allowed_age_groups: "thirties")
      end

      it "모든 조건 충족 시 eligible" do
        expect(meetup.eligible?(user)).to be true
      end

      it "하나라도 실패하면 ineligible" do
        wrong_gender = build(:user, :profile_complete, gender: :female, sport_level: :intermediate, age_group: :thirties)
        expect(meetup.eligible?(wrong_gender)).to be false
      end
    end
  end
end
