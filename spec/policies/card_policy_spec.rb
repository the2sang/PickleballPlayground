require "rails_helper"

RSpec.describe CardPolicy do
  def create_user(role: :user, nick_prefix: "u")
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

  let(:owned_deck) { Deck.create!(scope: :personal, owner: user, title: "내 덱") }
  let(:other_deck) { Deck.create!(scope: :personal, owner: other_user, title: "남의 덱") }

  let(:owned_card) { Card.create!(deck: owned_deck, front: "F", back: "B", position: 1) }
  let(:other_card) { Card.create!(deck: other_deck, front: "F", back: "B", position: 1) }

  describe "card on user's own deck" do
    subject(:policy) { described_class.new(user, owned_card) }

    it { expect(policy.show?).to be true }
    it { expect(policy.create?).to be true }
    it { expect(policy.update?).to be true }
    it { expect(policy.destroy?).to be true }
  end

  describe "card on another user's deck" do
    subject(:policy) { described_class.new(user, other_card) }

    it { expect(policy.show?).to be false }
    it { expect(policy.update?).to be false }
    it { expect(policy.destroy?).to be false }
  end

  describe "Scope" do
    it "returns empty relation (TODO phase-4)" do
      Card.create!(deck: owned_deck, front: "F", back: "B", position: 1)

      resolved = CardPolicy::Scope.new(user, Card.all).resolve
      expect(resolved).to be_empty
    end
  end
end
