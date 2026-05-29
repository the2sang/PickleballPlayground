require "rails_helper"

RSpec.describe DeckPolicy do
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
  let(:admin)      { create_user(role: :role_admin, nick_prefix: "admin") }

  let(:owned_deck) { Deck.create!(scope: :personal, owner: user, title: "내 덱") }
  let(:other_deck) { Deck.create!(scope: :personal, owner: other_user, title: "남의 덱") }

  describe "personal deck owned by user" do
    subject(:policy) { described_class.new(user, owned_deck) }

    it { expect(policy.show?).to be true }
    it { expect(policy.update?).to be true }
    it { expect(policy.destroy?).to be true }
  end

  describe "personal deck owned by another user" do
    subject(:policy) { described_class.new(user, other_deck) }

    it { expect(policy.show?).to be false }
    it { expect(policy.update?).to be false }
    it { expect(policy.destroy?).to be false }
  end

  describe "any authenticated user" do
    subject(:policy) { described_class.new(user, Deck.new) }
    it { expect(policy.create?).to be true }
    it { expect(policy.new?).to be true }
  end

  describe "nil user" do
    subject(:policy) { described_class.new(nil, owned_deck) }

    it { expect(policy.show?).to be false }
    it { expect(policy.update?).to be false }
    it { expect(policy.destroy?).to be false }
    it { expect(policy.create?).to be false }
  end

  describe "site_admin bypass" do
    subject(:policy) { described_class.new(admin, other_deck) }

    it "shows / updates / destroys other users' decks" do
      expect(policy.show?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end
  end

  describe "Scope" do
    it "returns empty relation (TODO phase-4)" do
      Deck.create!(scope: :personal, owner: user, title: "a")
      Deck.create!(scope: :personal, owner: other_user, title: "b")

      resolved = DeckPolicy::Scope.new(user, Deck.all).resolve
      expect(resolved).to be_empty
    end
  end
end
