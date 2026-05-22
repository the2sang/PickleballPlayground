require "rails_helper"

RSpec.describe TournamentTeam, type: :model do
  subject { build(:tournament_team) }

  describe "associations" do
    it { is_expected.to belong_to(:tournament_event) }
    it { is_expected.to have_many(:tournament_team_members).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:tournament_team_members) }
    it { is_expected.to have_many(:tournament_group_teams).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "#auto_name_from_members" do
    it "generates name from single member nickname" do
      user = build(:user, nickname: "홍길동")
      team = build(:tournament_team, name: "")
      allow(team).to receive_message_chain(:users, :pluck).and_return([ "홍길동" ])
      expect(team.auto_name_from_members).to eq("홍길동")
    end

    it "generates slash-separated name for two members" do
      team = build(:tournament_team, name: "")
      allow(team).to receive_message_chain(:users, :pluck).and_return([ "김철수", "이영희" ])
      expect(team.auto_name_from_members).to eq("김철수 / 이영희")
    end
  end
end
