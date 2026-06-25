class VotesController < ApplicationController
  allow_unauthenticated_access only: %i[index create]

  def index
    @votes_by_number = SloganVote.all.index_by(&:slogan_number)
    @slogan_vote = SloganVote.new
  end

  def create
    @slogan_vote = SloganVote.new(slogan_vote_params)

    if @slogan_vote.save
      redirect_to vote_path(anchor: "slogan_#{@slogan_vote.slogan_number}"),
                  notice: "표어가 성공적으로 선택되었습니다!",
                  status: :see_other
    else
      error_message = @slogan_vote.errors.full_messages.to_sentence
      redirect_to vote_path, alert: "저장에 실패했습니다: #{error_message}"
    end
  end

  private

  def slogan_vote_params
    params.require(:slogan_vote).permit(:slogan_number, :voter_name)
  end
end
