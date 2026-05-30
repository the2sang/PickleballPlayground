# frozen_string_literal: true

# SM-2 QUALITY_MAP는 코드 `{1=>1, 2=>3, 3=>4, 4=>5}`가 소스 오브 트루스 (Assumption A1, RESEARCH.md). D-22 문서값은 stale.
require "rails_helper"

RSpec.describe Flashcards::SubmitReviewService, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }
  let(:card) { create(:card, deck: deck) }

  describe ".call" do
    context "신규 카드 평가 (CardReview 미존재)" do
      it "rating=3 → CardReview row 신규 생성, last_rating=3" do
        expect {
          described_class.call(user: user, card_id: card.id, rating: 3)
        }.to change(CardReview, :count).by(1)

        cr = CardReview.last
        expect(cr.last_rating).to eq(3)
        expect(cr.last_reviewed_at).to be_within(5.seconds).of(Time.current)
      end

      it "rating=3 → ease가 SM-2 결과와 일치 (Pitfall 7: nil||2.5 기본값으로 계산)" do
        # SM-2: quality=4(rating=3), ease_floor=1.3, initial_ease=2.5
        # new_ease = max(2.5 + (0.1 - (5-4) * (0.08 + (5-4) * 0.02)), 1.3) = max(2.5 - 0.1, 1.3) = 2.4 ... wait
        # actually: 0.1 - (5-4)*(0.08 + (5-4)*0.02) = 0.1 - 1*(0.08 + 0.02) = 0.1 - 0.1 = 0.0
        # new_ease = max(2.5 + 0.0, 1.3) = 2.5
        expected = Flashcards::Sm2Service.call(ease: 2.5, interval_days: 0, repetitions: 0, rating: 3)
        result = described_class.call(user: user, card_id: card.id, rating: 3)

        expect(result.success?).to be true
        expect(result.card_review.ease).to be_within(0.01).of(expected.ease)
        expect(result.card_review.interval_days).to eq(expected.interval_days)
        expect(result.card_review.repetitions).to eq(expected.repetitions)
      end

      it "rating=1 → SM-2 매핑 quality=1 적용, interval_days=1, repetitions=0 (lapse)" do
        expected = Flashcards::Sm2Service.call(ease: 2.5, interval_days: 0, repetitions: 0, rating: 1)
        result = described_class.call(user: user, card_id: card.id, rating: 1)

        expect(result.success?).to be true
        expect(result.card_review.ease).to be_within(0.01).of(expected.ease)
        expect(result.card_review.interval_days).to eq(expected.interval_days)
        expect(result.card_review.repetitions).to eq(expected.repetitions)
        expect(result.card_review.last_rating).to eq(1)
      end

      it "rating=2 → SM-2 매핑 quality=3 적용" do
        expected = Flashcards::Sm2Service.call(ease: 2.5, interval_days: 0, repetitions: 0, rating: 2)
        result = described_class.call(user: user, card_id: card.id, rating: 2)

        expect(result.success?).to be true
        expect(result.card_review.ease).to be_within(0.01).of(expected.ease)
        expect(result.card_review.last_rating).to eq(2)
      end

      it "rating=4 → SM-2 매핑 quality=5 적용" do
        expected = Flashcards::Sm2Service.call(ease: 2.5, interval_days: 0, repetitions: 0, rating: 4)
        result = described_class.call(user: user, card_id: card.id, rating: 4)

        expect(result.success?).to be true
        expect(result.card_review.ease).to be_within(0.01).of(expected.ease)
        expect(result.card_review.last_rating).to eq(4)
      end

      it "성공 Result를 반환한다" do
        result = described_class.call(user: user, card_id: card.id, rating: 3)

        expect(result.success?).to be true
        expect(result.card_review).to be_persisted
        expect(result.errors).to be_empty
      end
    end

    context "기존 :due CardReview 재평가" do
      let!(:cr) { create(:card_review, :due, user: user, card: card) }

      it "rating=1 → ease 갱신, interval_days=1, repetitions=0 (lapse), last_rating=1" do
        original_ease = cr.ease
        result = described_class.call(user: user, card_id: card.id, rating: 1)

        expect(result.success?).to be true
        cr.reload
        expect(cr.interval_days).to eq(1)
        expect(cr.repetitions).to eq(0)
        expect(cr.last_rating).to eq(1)
        expect(cr.ease).not_to eq(original_ease) # SM-2 lapse reduces ease
      end

      it "기존 CardReview row를 새로 만들지 않는다" do
        expect {
          described_class.call(user: user, card_id: card.id, rating: 3)
        }.not_to change(CardReview, :count)
      end

      it "last_reviewed_at이 현재 시각으로 업데이트된다" do
        described_class.call(user: user, card_id: card.id, rating: 3)
        cr.reload
        expect(cr.last_reviewed_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context "RecordNotUnique 복구" do
      it "동일 (user, card)로 이미 CardReview가 있을 때 단일 row가 유지된다" do
        # 사전에 CardReview 존재 — 이미 생성된 상태에서 서비스 호출
        create(:card_review, :due, user: user, card: card)

        expect {
          described_class.call(user: user, card_id: card.id, rating: 3)
        }.not_to change(CardReview, :count)

        expect(CardReview.where(user: user, card: card).count).to eq(1)
      end
    end

    context "잘못된 rating" do
      it "rating=0 → ArgumentError를 발생시킨다 (SM2Service VALID_RATINGS 가드)" do
        expect {
          described_class.call(user: user, card_id: card.id, rating: 0)
        }.to raise_error(ArgumentError)
      end

      it "rating=5 → ArgumentError를 발생시킨다 (SM2Service VALID_RATINGS 가드)" do
        expect {
          described_class.call(user: user, card_id: card.id, rating: 5)
        }.to raise_error(ArgumentError)
      end
    end
  end
end
