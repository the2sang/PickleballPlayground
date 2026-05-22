module FlashMeetups
  class CancelParticipationService
    Result = Struct.new(:success?, :errors, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(participation:)
      @participation = participation
    end

    def call
      ActiveRecord::Base.transaction do
        @participation.update!(status: :cancelled)
        promote_next_from_waitlist
      end

      Result.new(success?: true, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, errors: [ e.message ])
    end

    private

    def promote_next_from_waitlist
      next_waiting = @participation.flash_meetup
                                   .flash_meetup_participations
                                   .waitlisted
                                   .order(:created_at)
                                   .first
      next_waiting&.promote_from_waitlist!
    end
  end
end
