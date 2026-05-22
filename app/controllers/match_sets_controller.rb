class MatchSetsController < ApplicationController
  before_action :set_match,     only: %i[create]
  before_action :set_match_set, only: %i[update destroy]

  def create
    @match_set = @match.match_sets.build(match_set_params)
    authorize @match_set
    if @match_set.save
      redirect_to @match, notice: "세트 스코어가 저장되었습니다."
    else
      redirect_to @match, alert: @match_set.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @match_set
    if @match_set.update(match_set_params)
      redirect_to @match_set.match, notice: "세트 스코어가 수정되었습니다."
    else
      redirect_to @match_set.match, alert: @match_set.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @match_set
    match = @match_set.match
    @match_set.destroy!
    redirect_to match, notice: "세트 스코어가 삭제되었습니다."
  end

  private

  def set_match     = @match     = Match.find(params[:match_id])
  def set_match_set = @match_set = MatchSet.find(params[:id])

  def match_set_params
    params.require(:match_set).permit(:set_number, :home_score, :away_score)
  end
end
