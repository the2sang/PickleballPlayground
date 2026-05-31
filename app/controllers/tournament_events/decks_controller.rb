# frozen_string_literal: true

module TournamentEvents
  class DecksController < ApplicationController
    before_action :set_event

    def edit
      authorize @event, :manage_decks?
      @candidate_decks = candidate_decks
      @selected_deck_ids = @event.tournament_event_decks.order(:position).pluck(:deck_id)
    end

    def update
      authorize @event, :manage_decks?
      deck_ids = Array(params[:deck_ids]).map(&:to_i).uniq

      ActiveRecord::Base.transaction do
        TournamentEventDeck.where(tournament_event: @event).destroy_all
        deck_ids.each_with_index do |deck_id, position|
          @event.tournament_event_decks.create!(deck_id: deck_id, position: position)
        end
      end

      redirect_to @event, notice: "추천 덱이 업데이트되었습니다."
    rescue ActiveRecord::RecordInvalid => e
      @candidate_decks  = candidate_decks
      @selected_deck_ids = Array(params[:deck_ids]).map(&:to_i)
      flash.now[:alert] = "저장 실패: #{e.message}"
      render :edit, status: :unprocessable_entity
    end

    private

    def set_event
      @event = TournamentEvent.find(params[:tournament_event_id])
    end

    def candidate_decks
      official_decks   = Deck.where(scope: :official).order(:title)
      manager_club_ids = Current.user.club_memberships.approved
                                     .where(role: :manager)
                                     .pluck(:club_id)
      club_decks       = manager_club_ids.any? ?
        Deck.where(scope: :club, owner_type: "Club", owner_id: manager_club_ids).order(:title) : []
      (official_decks.to_a + club_decks.to_a).uniq
    end
  end
end
