require "rails_helper"

RSpec.describe CardReviewPolicy do
  def create_user(role: :role_user, nick_prefix: "u")
    User.create!(
      email_address: "#{nick_prefix}#{SecureRandom.hex(3)}@example.com",
      nickname:      "#{nick_prefix}#{SecureRandom.hex(3)}",
      password:      "password",
      role:          role,
      sport_level:   :beginner,
      age_group:     :twenties,
      gender:        :unspecified
    )
  end

  let(:user)       { create_user(nick_prefix: "owner") }
  let(:other_user) { create_user(nick_prefix: "other") }

  let(:deck) { Deck.create!(scope: :personal, owner: user, title: "내 덱") }
  let(:card) { Card.create!(deck: deck, front: "F", back: "B", position: 1) }
  let(:own_review)   { CardReview.create!(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0) }
  let(:other_review) { CardReview.create!(user: other_user, card: card, ease: 2.5, interval_days: 0, repetitions: 0) }

  describe "review belonging to user" do
    subject(:policy) { described_class.new(user, own_review) }

    it { expect(policy.show?).to be true }
    it { expect(policy.create?).to be true }
    it { expect(policy.update?).to be true }
    it { expect(policy.destroy?).to be true }
  end

  describe "review belonging to another user" do
    subject(:policy) { described_class.new(user, other_review) }

    it { expect(policy.show?).to be false }
    it { expect(policy.create?).to be false }
    it { expect(policy.update?).to be false }
    it { expect(policy.destroy?).to be false }
  end

  describe "nil user" do
    subject(:policy) { described_class.new(nil, own_review) }

    it { expect(policy.create?).to be false }
    it { expect(policy.show?).to be false }
  end

  describe "Scope" do
    it "filters by user_id for authenticated user" do
      r1 = CardReview.create!(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0)
      _r2 = CardReview.create!(user: other_user, card: card, ease: 2.5, interval_days: 0, repetitions: 0)

      resolved = CardReviewPolicy::Scope.new(user, CardReview.all).resolve
      expect(resolved.to_a).to eq([ r1 ])
    end

    it "returns empty for nil user" do
      CardReview.create!(user: user, card: card, ease: 2.5, interval_days: 0, repetitions: 0)
      resolved = CardReviewPolicy::Scope.new(nil, CardReview.all).resolve
      expect(resolved).to be_empty
    end
  end
end
