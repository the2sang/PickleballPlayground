module FlashMeetups
  class CreateParticipationService
    Result = Struct.new(:success?, :participation, :errors, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(flash_meetup:, user:)
      @flash_meetup = flash_meetup
      @user = user
    end

    def call
      return failure("모임이 마감되었습니다.") if @flash_meetup.full?
      return failure("참가 자격이 없습니다.") unless @flash_meetup.eligible?(@user)

      status = @flash_meetup.full? ? :waitlisted : :confirmed

      existing = @flash_meetup.flash_meetup_participations.cancelled.find_by(user: @user)
      participation = existing || @flash_meetup.flash_meetup_participations.build(user: @user)
      participation.status = status

      if participation.save
        Result.new(success?: true, participation: participation, errors: [])
      else
        Result.new(success?: false, participation: participation,
                   errors: participation.errors.full_messages)
      end
    end

    private

    def failure(message)
      Result.new(success?: false, participation: nil, errors: [ message ])
    end
  end
end
