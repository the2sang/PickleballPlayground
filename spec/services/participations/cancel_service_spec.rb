require "rails_helper"

RSpec.describe Participations::CancelService do
  subject(:result) { described_class.call(participation: participation) }

  let(:session) { create(:game_session, max_participants: 2) }

  describe "확정자 취소" do
    let!(:confirmed) { create(:participation, :profile_complete_user, game_session: session, status: :confirmed) }
    let(:participation) { confirmed }

    context "대기자가 있을 때" do
      let!(:waitlisted) do
        create(:participation, :profile_complete_user, :waitlisted, game_session: session)
      end

      it "대기 순번 1번을 confirmed 로 승급시킨다" do
        expect { result }.to change { waitlisted.reload.status }.from("waitlisted").to("confirmed")
        expect(result.success?).to be true
        expect(confirmed.reload).to be_cancelled
      end

      it "가장 먼저 신청한 대기자만 승급시킨다" do
        later = create(:participation, :profile_complete_user, :waitlisted, game_session: session)
        result
        expect(waitlisted.reload).to be_confirmed
        expect(later.reload).to be_waitlisted
      end
    end

    context "대기자가 없을 때" do
      it "승급 없이 취소만 처리한다" do
        expect(result.success?).to be true
        expect(confirmed.reload).to be_cancelled
      end
    end
  end

  describe "대기자 취소" do
    let!(:confirmed) { create(:participation, :profile_complete_user, game_session: session, status: :confirmed) }
    let(:participation) do
      create(:participation, :profile_complete_user, :waitlisted, game_session: session)
    end

    it "다른 참가자를 승급시키지 않는다" do
      result
      expect(participation.reload).to be_cancelled
      expect(confirmed.reload).to be_confirmed
    end
  end
end
