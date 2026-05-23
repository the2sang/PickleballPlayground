module GameSessions
  class CreateRecurringInstancesJob < ApplicationJob
    queue_as :default

    def perform(date = Date.current)
      GameSession.templates.find_each do |template|
        next unless template.should_run_today?(date)

        GameSession.create!(
          club:             template.club,
          title:            template.title,
          venue_name:       template.venue_name,
          address:          template.address,
          scheduled_date:   date,
          start_time:       template.start_time,
          end_time:         template.end_time,
          court_count:      template.court_count,
          fee:              template.fee,
          notes:            template.notes,
          max_participants: template.max_participants,
          visibility:       template.visibility,
          template_id:      template.id,
          status:           :open
        )
      rescue ActiveRecord::RecordNotUnique
        # already created by a concurrent job invocation — safe to skip
      end
    end
  end
end
