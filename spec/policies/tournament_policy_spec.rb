require "rails_helper"

RSpec.describe TournamentPolicy, type: :policy do
  let(:owner)   { create(:user) }
  let(:manager_user) { create(:user) }
  let(:member)  { create(:user) }
  let(:other)   { create(:user) }
  let(:admin)   { create(:user, :admin) }
  let(:club)    { create(:club, owner: owner) }
  let(:tournament) { create(:tournament, club: club) }

  before do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
    create(:club_membership, club: club, user: member, role: :member, status: :approved)
  end

  def policy(user) = described_class.new(user, tournament)

  describe "#index? / #show?" do
    it "누구나 허용" do
      expect(described_class.new(nil, tournament).index?).to be true
      expect(described_class.new(nil, tournament).show?).to be true
      expect(policy(other).index?).to be true
    end
  end

  describe "#create? / #update?" do
    it "비로그인 거부" do
      expect(described_class.new(nil, tournament).create?).to be false
    end

    it "일반 회원 거부" do
      expect(policy(other).create?).to be false
      expect(policy(member).create?).to be false
    end

    it "클럽 오너 허용" do
      expect(policy(owner).create?).to be true
      expect(policy(owner).update?).to be true
    end

    it "클럽 매니저 허용" do
      expect(policy(manager_user).create?).to be true
      expect(policy(manager_user).update?).to be true
    end

    it "어드민 허용" do
      expect(policy(admin).create?).to be true
      expect(policy(admin).update?).to be true
    end
  end

  describe "#destroy?" do
    it "draft 상태에서 오너 허용" do
      expect(policy(owner).destroy?).to be true
    end

    it "draft 상태에서 매니저 허용" do
      expect(policy(manager_user).destroy?).to be true
    end

    it "draft 아닌 상태에서 오너 거부" do
      tournament.update!(status: :in_progress)
      expect(policy(owner).destroy?).to be false
    end

    it "어드민은 상태 무관 허용" do
      tournament.update!(status: :in_progress)
      expect(policy(admin).destroy?).to be true
    end

    it "일반 유저 거부" do
      expect(policy(other).destroy?).to be false
    end
  end

  describe "Scope" do
    it "모든 대회 반환" do
      t2 = create(:tournament, club: club)
      scope = described_class::Scope.new(nil, Tournament).resolve
      expect(scope).to include(tournament, t2)
    end
  end
end
