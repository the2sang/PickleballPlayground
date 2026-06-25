require 'rails_helper'

RSpec.describe "Votes", type: :request do
  describe "GET /vote" do
    it "renders the slogan list successfully even when unauthenticated" do
      get vote_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("2026년 국가 보안 표어/표스터 공모전 시행")
      expect(response.body).to include("보안은 눈치가 아니라, 눈으로 확인!")
    end

    it "renders already selected slogans with line-through and the voter name" do
      SloganVote.create!(slogan_number: 1, voter_name: "이순신")
      
      get vote_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("선택자: 이순신")
      expect(response.body).to include("line-through")
    end
  end

  describe "POST /vote" do
    context "with valid parameters" do
      it "creates a new SloganVote and redirects back with a scroll anchor" do
        expect {
          post votes_path, params: { slogan_vote: { slogan_number: 5, voter_name: "홍길동" } }
        }.to change(SloganVote, :count).by(1)

        expect(response).to redirect_to(vote_path(anchor: "slogan_5"))
        follow_redirect!
        expect(response.body).to include("표어가 성공적으로 선택되었습니다!")
      end
    end

    context "with invalid parameters (blank name)" do
      it "does not create a SloganVote and redirects back with alert" do
        expect {
          post votes_path, params: { slogan_vote: { slogan_number: 6, voter_name: "" } }
        }.not_to change(SloganVote, :count)

        expect(response).to redirect_to(vote_path)
        follow_redirect!
        expect(response.body).to include("저장에 실패했습니다")
      end
    end

    context "when slogan is already voted by someone else" do
      before do
        SloganVote.create!(slogan_number: 10, voter_name: "홍길동")
      end

      it "fails to vote and redirects back with alert" do
        expect {
          post votes_path, params: { slogan_vote: { slogan_number: 10, voter_name: "이순신" } }
        }.not_to change(SloganVote, :count)

        expect(response).to redirect_to(vote_path)
        follow_redirect!
        expect(response.body).to include("저장에 실패했습니다")
      end
    end
  end
end
