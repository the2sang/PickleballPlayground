require "rails_helper"

RSpec.describe "Admin::DeckAdditionRequests", type: :request do
  describe "PATCH /admin/deck_addition_requests/:id" do
    it "approves a pending deck addition request" do
      admin = create(:user, :admin)
      user = create(:user)
      request = create(:deck_addition_request, user: user)
      sign_in(admin)

      patch admin_deck_addition_request_path(request)

      expect(response).to redirect_to(admin_root_path)
      expect(request.reload).to be_approved
      expect(request.approved_by).to eq(admin)
      expect(user.personal_deck_limit).to eq(Deck::PERSONAL_DECK_LIMIT + 1)
    end
  end
end
