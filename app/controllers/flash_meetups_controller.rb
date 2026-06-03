class FlashMeetupsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  before_action :resume_session, only: %i[index show]
  before_action :set_flash_meetup, only: %i[show edit update destroy]

  def index
    @flash_meetups = policy_scope(FlashMeetup).upcoming.with_organizer
  end

  def show
    authorize @flash_meetup

    @flash_meetup = FlashMeetup.includes(flash_meetup_participations: :user).find(params[:id])
    @my_participation = Current.user&.flash_meetup_participations&.find_by(flash_meetup: @flash_meetup)
  end

  def new
    @flash_meetup = FlashMeetup.new
    authorize @flash_meetup
  end

  def create
    @flash_meetup = Current.user.flash_meetups.build(flash_meetup_params)
    authorize @flash_meetup
    if @flash_meetup.save
      redirect_to @flash_meetup, notice: "번개모임이 개설되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @flash_meetup
  end

  def update
    authorize @flash_meetup
    if @flash_meetup.update(flash_meetup_params)
      redirect_to @flash_meetup, notice: "번개모임이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @flash_meetup
    @flash_meetup.destroy!
    redirect_to flash_meetups_path, notice: "번개모임이 삭제되었습니다."
  end

  private

  def set_flash_meetup
    @flash_meetup = FlashMeetup.find(params[:id])
  end

  def flash_meetup_params
    p = params.require(:flash_meetup).permit(
      :venue_name, :address,
      :start_date, :end_date, :start_time, :end_time,
      :scheduled_at, :ends_at, :max_participants,
      :gender_filter, :level_filter, :kakao_open_chat_url, :hot_zone,
      allowed_age_groups: []
    )
    if p[:allowed_age_groups].present?
      p[:allowed_age_groups] = p[:allowed_age_groups].reject(&:blank?).join(",")
    end
    p
  end
end
