module Flashcards
  # Fork an existing Deck (any scope) into a new personal Deck owned by `user`.
  #
  # Contract (per ADR-0001 + <interfaces> in 01-01-PLAN.md):
  #   - Wraps Deck/Card inserts in ActiveRecord::Base.transaction
  #   - Renormalizes child Card positions to contiguous 1..n (PITFALLS §7)
  #   - Does NOT copy CardReview rows — per-user SRS state stays with original cards
  #   - Does NOT copy ActiveStorage attachments in v1 (image UI is hidden)
  #   - Trusts caller to have authorized the source (no internal auth check)
  #
  # Caller (Phase 4 controller) is responsible for `authorize @source_deck, :fork?`.
  class ForkDeckService
    Result = Struct.new(:success?, :deck, :errors, keyword_init: true)

    def self.call(**args) = new(**args).call

    def initialize(source:, user:)
      @source = source
      @user   = user
    end

    def call
      new_deck = nil

      ActiveRecord::Base.transaction do
        new_deck = Deck.create!(
          scope:       :personal,
          owner:       @user,
          forked_from: @source,
          title:       @source.title,
          description: @source.description,
          category:    @source.category
        )

        @source.cards.ordered.each_with_index do |source_card, idx|
          new_deck.cards.create!(
            front:     source_card.front,
            back:      source_card.back,
            hint:      source_card.hint,
            tags:      source_card.tags,
            card_type: source_card.card_type,
            position:  idx + 1
          )
        end
      end

      Result.new(success?: true, deck: new_deck, errors: [])
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Result.new(success?: false, deck: nil, errors: [ e.message ])
    end
  end
end
