class FlashMeetupParticipationsController < ApplicationController
  before_action :set_flash_meetup
  before_action :set_participation, only: %i[destroy]

  def create
    @participation = @flash_meetup.flash_meetup_participations.build(user: Current.user)
    authorize @participation

    result = FlashMeetups::CreateParticipationService.call(
      flash_meetup: @flash_meetup,
      user: Current.user
    )

    if result.success?
      redirect_to @flash_meetup, notice: participation_notice(result.participation)
    else
      redirect_to @flash_meetup, alert: result.errors.first
    end
  end

  def destroy
    authorize @participation

    result = FlashMeetups::CancelParticipationService.call(participation: @participation)

    if result.success?
      redirect_to @flash_meetup, notice: "참가 신청이 취소되었습니다."
    else
      redirect_to @flash_meetup, alert: result.errors.first
    end
  end

  private

  def set_flash_meetup
    @flash_meetup = FlashMeetup.find(params[:flash_meetup_id])
  end

  def set_participation
    @participation = @flash_meetup.flash_meetup_participations.find(params[:id])
  end

  def participation_notice(participation)
    participation.confirmed? ? "참가 신청이 완료되었습니다." : "대기자로 등록되었습니다."
  end
end
