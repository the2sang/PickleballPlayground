# app/services/flashcards/due_count_cache_service.rb
# frozen_string_literal: true

module Flashcards
  class DueCountCacheService
    CACHE_KEY = ->(user_id) { "flashcards/due_count/#{user_id}" }
    TTL = 1.hour

    def self.fetch(user)
      Rails.cache.fetch(CACHE_KEY.call(user.id), expires_in: TTL) do
        TodayProgressQuery.call(user: user)[:due_remaining]
      end
    end

    def self.invalidate(user)
      Rails.cache.delete(CACHE_KEY.call(user.id))
    end
  end
end
