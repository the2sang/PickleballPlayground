module Participations
  class CancelService
    Result = Struct.new(:success?, :errors, keyword_init: true)

    def self.call(participation:) = new(participation: participation).call

    def initialize(participation:)
      @participation = participation
    end

    def call
      # 세션 행을 잠가 동시 취소 시 대기자가 중복 승급되는 경합을 방지한다.
      @participation.game_session.with_lock do
        was_confirmed = @participation.confirmed?
        @participation.cancelled!
        promote_waitlist if was_confirmed
      end
      Result.new(success?: true, errors: [])
    end

    private

    def promote_waitlist
      next_in_line = @participation.game_session
                                   .participations
                                   .waitlisted
                                   .order(:created_at)
                                   .first
      next_in_line&.confirmed!
    end
  end
end
