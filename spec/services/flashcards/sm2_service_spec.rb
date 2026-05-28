require "rails_helper"

RSpec.describe Flashcards::Sm2Service do
  describe "constants" do
    it "QUALITY_MAP is exactly { 1=>1, 2=>3, 3=>4, 4=>5 } and frozen" do
      expect(described_class::QUALITY_MAP).to eq(1 => 1, 2 => 3, 3 => 4, 4 => 5)
      expect(described_class::QUALITY_MAP).to be_frozen
    end

    it "EASE_FLOOR is 1.3" do
      expect(described_class::EASE_FLOOR).to eq(1.3)
    end

    it "INITIAL_EASE is 2.5" do
      expect(described_class::INITIAL_EASE).to eq(2.5)
    end

    it "VALID_RATINGS is [1,2,3,4]" do
      expect(described_class::VALID_RATINGS).to eq([ 1, 2, 3, 4 ])
    end
  end

  describe "rating validation" do
    let(:base) { { ease: 2.5, interval_days: 0, repetitions: 0 } }

    [ 0, 5, -1, "1", nil ].each do |bad|
      it "raises ArgumentError for rating=#{bad.inspect}" do
        expect { described_class.call(**base, rating: bad) }
          .to raise_error(ArgumentError, /rating must be one of/)
      end
    end
  end

  # === Boundary table — 4 ratings × 2 starting states = 8 pinned cases ===
  describe "fresh card (ease=2.5, interval=0, repetitions=0)" do
    let(:base) { { ease: 2.5, interval_days: 0, repetitions: 0 } }

    {
      1 => { ease: 1.96, interval_days: 1, repetitions: 0 },
      2 => { ease: 2.36, interval_days: 1, repetitions: 1 },
      3 => { ease: 2.5,  interval_days: 1, repetitions: 1 },
      4 => { ease: 2.6,  interval_days: 1, repetitions: 1 }
    }.each do |rating, expected|
      it "rating=#{rating} -> ease=#{expected[:ease]}, interval=#{expected[:interval_days]}, reps=#{expected[:repetitions]}" do
        result = described_class.call(**base, rating: rating)
        expect(result.ease).to           eq(expected[:ease])
        expect(result.interval_days).to  eq(expected[:interval_days])
        expect(result.repetitions).to    eq(expected[:repetitions])
      end
    end
  end

  describe "mature card (ease=2.4, interval=14, repetitions=3)" do
    let(:base) { { ease: 2.4, interval_days: 14, repetitions: 3 } }

    {
      1 => { ease: 1.86, interval_days: 1,  repetitions: 0 },
      2 => { ease: 2.26, interval_days: 32, repetitions: 4 },
      3 => { ease: 2.4,  interval_days: 34, repetitions: 4 },
      4 => { ease: 2.5,  interval_days: 35, repetitions: 4 }
    }.each do |rating, expected|
      it "rating=#{rating} -> ease=#{expected[:ease]}, interval=#{expected[:interval_days]}, reps=#{expected[:repetitions]}" do
        result = described_class.call(**base, rating: rating)
        expect(result.ease).to           eq(expected[:ease])
        expect(result.interval_days).to  eq(expected[:interval_days])
        expect(result.repetitions).to    eq(expected[:repetitions])
      end
    end
  end

  describe "ease floor — clamped at 1.3" do
    it "ease=1.3, rating=1 -> result.ease == 1.3 (no negative drift)" do
      result = described_class.call(ease: 1.3, interval_days: 1, repetitions: 0, rating: 1)
      expect(result.ease).to eq(1.3)
    end
  end

  describe "second-rep transition (`case reps when 1 then 6`)" do
    it "ease=2.5, interval=1, reps=1, rating=3 -> (ease: 2.5, interval: 6, reps: 2)" do
      result = described_class.call(ease: 2.5, interval_days: 1, repetitions: 1, rating: 3)
      expect(result.ease).to          eq(2.5)
      expect(result.interval_days).to eq(6)
      expect(result.repetitions).to   eq(2)
    end
  end

  describe "now: injection" do
    it "next_review_at == now + interval.days" do
      frozen_now = Time.zone.parse("2026-05-29 12:00:00")
      result = described_class.call(
        ease: 2.5, interval_days: 0, repetitions: 0, rating: 3, now: frozen_now
      )
      expect(result.next_review_at).to eq(frozen_now + result.interval_days.days)
    end
  end

  describe "structural properties" do
    let(:base) { { ease: 2.5, interval_days: 0, repetitions: 0 } }

    [ 1, 2, 3, 4 ].each do |rating|
      it "rating=#{rating}: ease >= EASE_FLOOR and interval_days >= 1" do
        result = described_class.call(**base, rating: rating)
        expect(result.ease).to be >= described_class::EASE_FLOOR
        expect(result.interval_days).to be >= 1
      end
    end

    [ 1 ].each do |lapse_rating|
      it "lapse (rating=#{lapse_rating}): repetitions reset to 0 and interval is 1" do
        result = described_class.call(ease: 2.4, interval_days: 14, repetitions: 3, rating: lapse_rating)
        expect(result.repetitions).to   eq(0)
        expect(result.interval_days).to eq(1)
      end
    end
  end

  describe "Result struct shape" do
    it "responds to ease/interval_days/repetitions/next_review_at" do
      result = described_class.call(ease: 2.5, interval_days: 0, repetitions: 0, rating: 3)
      expect(result).to respond_to(:ease, :interval_days, :repetitions, :next_review_at)
    end
  end
end
