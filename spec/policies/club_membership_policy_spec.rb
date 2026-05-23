require "rails_helper"

RSpec.describe ClubMembershipPolicy, type: :policy do
  let(:owner)        { create(:user) }
  let(:manager_user) { create(:user) }
  let(:member_user)  { create(:user) }
  let(:other)        { create(:user) }
  let(:club)         { create(:club, owner: owner) }

  let(:manager_membership) do
    create(:club_membership, club: club, user: manager_user, role: :manager, status: :approved)
  end
  let(:member_membership) do
    create(:club_membership, club: club, user: member_user, role: :member, status: :approved)
  end

  before { manager_membership; member_membership }

  def policy(user, record) = described_class.new(user, record)

  describe "#update?" do
    context "매니저가 다른 회원의 멤버십 수정" do
      it "허용" do
        expect(policy(manager_user, member_membership).update?).to be true
      end
    end

    context "회원이 자신의 멤버십을 withdrawal_requested로 변경 요청" do
      before { member_membership.status = :withdrawal_requested }

      it "본인은 허용" do
        expect(policy(member_user, member_membership).update?).to be true
      end

      it "타인은 거부" do
        expect(policy(other, member_membership).update?).to be false
      end
    end

    context "회원이 자신의 멤버십을 approved로 되돌리기 (신청 취소)" do
      before do
        member_membership.update!(status: :withdrawal_requested)
        member_membership.status = :approved
      end

      it "본인은 허용" do
        expect(policy(member_user, member_membership).update?).to be true
      end
    end

    context "비로그인" do
      it "거부" do
        expect(policy(nil, member_membership).update?).to be false
      end
    end
  end

  describe "#destroy?" do
    it "본인 탈퇴 허용" do
      expect(policy(member_user, member_membership).destroy?).to be true
    end

    it "매니저 강제 탈퇴 허용" do
      expect(policy(manager_user, member_membership).destroy?).to be true
    end

    it "타인 거부" do
      expect(policy(other, member_membership).destroy?).to be false
    end
  end
end
