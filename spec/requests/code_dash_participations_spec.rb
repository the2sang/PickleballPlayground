require "rails_helper"

RSpec.describe "CodeDashParticipations", type: :request do
  let(:club) { create(:club, status: :approved) }
  let(:game_session) do
    GameSession.create!(
      club: club,
      title: "토요 정기 운동",
      venue_name: "센터 코트",
      scheduled_date: Date.current + 1.day,
      start_time: "10:00",
      end_time: "12:00",
      court_count: 2,
      fee: 0,
      status: :open
    )
  end
  let(:member) { create(:user, code_dash_key: "QWERTY") }

  it "renders the Code Dash participation modal on the game session page" do
    get game_session_path(game_session)

    expect(response.body).to include("참가 신청하기")
    expect(response.body).to include("Code Dash 접속키")
    expect(response.body).to include("로그인 인증")
    expect(response.body).to include(new_session_path(return_to: new_game_session_participation_path(game_session)))
    expect(response.body).to include(game_session_code_dash_participation_path(game_session))
  end

  it "creates a member participation when the access key belongs to an approved club member" do
    create(:club_membership, club: club, user: member, status: :approved)

    expect {
      post game_session_code_dash_participation_path(game_session), params: { code_dash_key: "qwe-rty" }
    }.to change { game_session.participations.active.count }.by(1)
      .and change { member.sessions.count }.by(1)

    participation = game_session.participations.find_by(user: member)
    expect(participation).to be_as_member
    expect(response).to redirect_to(game_session_path(game_session))
    expect(member.reload.code_dash_key_last_used_at).to be_present
  end

  it "does not create a participation for a user who is not an approved club member" do
    create(:club_membership, club: club, user: member, status: :pending)

    expect {
      post game_session_code_dash_participation_path(game_session), params: { code_dash_key: "QWERTY" }
    }.not_to change { Participation.count }

    expect(response).to redirect_to(game_session_path(game_session, code_dash: 1))
  end

  it "redirects to login authentication after three failed access key attempts" do
    2.times do
      post game_session_code_dash_participation_path(game_session), params: { code_dash_key: "ZZZZZZ" }
      expect(response).to redirect_to(game_session_path(game_session, code_dash: 1))
    end

    post game_session_code_dash_participation_path(game_session), params: { code_dash_key: "ZZZZZZ" }

    expect(response).to redirect_to(new_session_path(return_to: game_session_path(game_session)))
    expect(game_session.participations.count).to eq(0)
  end
end
