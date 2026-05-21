class ProfilesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if params[:terms_agreed] != "1" || params[:privacy_agreed] != "1"
      @user.errors.add(:base, "이용약관 및 개인정보 수집·이용에 모두 동의해 주세요.")
      return render :edit, status: :unprocessable_entity
    end

    dupr_id_changed = params.dig(:user, :dupr_id).to_s != @user.dupr_id.to_s

    if @user.update(profile_params.merge(profile_completed_at: Time.current))
      Users::SyncDuprRatingJob.perform_later(@user.id) if dupr_id_changed && @user.dupr_id.present?
      after = params[:redirect_after].presence
      after = nil unless after&.start_with?("/")
      redirect_to(after || session.delete(:return_to) || root_path, notice: "기본 정보가 저장되었습니다.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def dupr_lookup
    dupr_id = params[:dupr_id].to_s.strip
    return render json: { error: "DUPR ID를 입력해 주세요." }, status: :bad_request if dupr_id.blank?

    result = Users::FetchDuprRatingService.call(dupr_id: dupr_id)

    if result.success?
      render json: { rating: result.rating }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:display_name, :sport_level, :gender, :age_group, :region, :dupr_id)
  end
end
