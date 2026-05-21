class MatchesController < ApplicationController
  allow_unauthenticated_access only: %i[show]
  before_action :resume_session, only: %i[show]
  before_action :set_match

  def show
    authorize @match
    @sets = @match.match_sets.order(:set_number)
  end

  def edit
    authorize @match
    @sets = @match.match_sets.order(:set_number)
  end

  def update
    authorize @match
    sets = extract_sets(params)
    result = Matches::RecordResultService.call(match: @match, sets: sets)
    if result.success?
      flash[:notice] = result.warning || "경기 결과가 저장되었습니다."
      redirect_to @match
    else
      redirect_to edit_match_path(@match), alert: result.error
    end
  end

  def advance_winner
    authorize @match, :update?
    result = TournamentBracket::AdvanceWinnerService.call(match: @match)
    if result.success?
      redirect_to @match, notice: "승자가 다음 라운드에 배정되었습니다."
    else
      redirect_to @match, alert: result.error
    end
  end

  private

  def set_match
    @match = Match.includes(:home_team, :away_team, :winner, :match_sets).find(params[:id])
  end

  def extract_sets(params)
    raw = params.permit(sets: %i[home_score away_score])[:sets]
    return [] if raw.blank?
    raw.values.map { |s| { home_score: s[:home_score].to_i, away_score: s[:away_score].to_i } }
  end
end
