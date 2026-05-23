require "rails_helper"

RSpec.describe "CodeDashSessions", type: :request do
  let(:club) { create(:club, status: :approved) }
  let(:user) { create(:user, code_dash_key: "QWERTY") }

  it "logs in an approved club member with only their codedash key" do
    create(:club_membership, club: club, user: user, status: :approved)

    expect {
      post club_code_dash_session_path(club), params: { code_dash_key: "qwe-rty" }
    }.to change { user.sessions.count }.by(1)

    expect(response).to redirect_to(club_path(club))
    expect(user.reload.code_dash_key_last_used_at).to be_present
  end

  it "uses the same codedash key for every approved club membership" do
    other_club = create(:club, status: :approved)
    create(:club_membership, club: club, user: user, status: :approved)
    create(:club_membership, club: other_club, user: user, status: :approved)

    expect {
      post club_code_dash_session_path(other_club), params: { code_dash_key: "QWERTY" }
    }.to change { user.sessions.count }.by(1)

    expect(response).to redirect_to(club_path(other_club))
  end

  it "does not log in a user who is not approved for the club" do
    create(:club_membership, club: club, user: user, status: :pending)

    expect {
      post club_code_dash_session_path(club), params: { code_dash_key: "QWERTY" }
    }.not_to change { user.sessions.count }

    expect(response).to redirect_to(club_path(club))
  end

  it "does not log in with an unknown codedash key" do
    create(:club_membership, club: club, user: user, status: :approved)

    expect {
      post club_code_dash_session_path(club), params: { code_dash_key: "ZZZZZZ" }
    }.not_to change { user.sessions.count }

    expect(response).to redirect_to(club_path(club))
  end
end
