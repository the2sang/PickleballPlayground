require 'rails_helper'

RSpec.describe SloganVote, type: :model do
  describe "validations" do
    it "is valid with a slogan_number and voter_name" do
      vote = SloganVote.new(slogan_number: 1, voter_name: "홍길동")
      expect(vote).to be_valid
    end

    it "is invalid without a slogan_number" do
      vote = SloganVote.new(slogan_number: nil, voter_name: "홍길동")
      expect(vote).not_to be_valid
      expect(vote.errors[:slogan_number]).to be_present
    end

    it "is invalid if slogan_number is not in range 1..99" do
      vote_zero = SloganVote.new(slogan_number: 0, voter_name: "홍길동")
      vote_hundred = SloganVote.new(slogan_number: 100, voter_name: "홍길동")
      
      expect(vote_zero).not_to be_valid
      expect(vote_hundred).not_to be_valid
    end

    it "is invalid without a voter_name" do
      vote = SloganVote.new(slogan_number: 1, voter_name: "")
      expect(vote).not_to be_valid
    end

    it "is invalid if slogan_number is duplicated" do
      SloganVote.create!(slogan_number: 1, voter_name: "홍길동")
      duplicate_vote = SloganVote.new(slogan_number: 1, voter_name: "이순신")
      
      expect(duplicate_vote).not_to be_valid
      expect(duplicate_vote.errors[:slogan_number]).to be_present
    end
  end

  describe "#slogan_text" do
    it "returns the correct slogan text corresponding to its number" do
      vote = SloganVote.new(slogan_number: 1)
      expect(vote.slogan_text).to eq("보안은 눈치가 아니라, 눈으로 확인!")
    end
  end
end
