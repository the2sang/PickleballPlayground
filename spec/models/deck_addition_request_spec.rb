require "rails_helper"

RSpec.describe DeckAdditionRequest, type: :model do
  describe "approval" do
    it "records the admin and approval time" do
      admin = create(:user, :admin)
      request = create(:deck_addition_request)

      freeze_time do
        request.approve!(admin)

        expect(request).to be_approved
        expect(request.approved_by).to eq(admin)
        expect(request.approved_at).to eq(Time.current)
      end
    end
  end

  describe "pending request uniqueness" do
    it "allows only one pending request per user" do
      user = create(:user)
      create(:deck_addition_request, user: user)

      duplicate = build(:deck_addition_request, user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end
end
