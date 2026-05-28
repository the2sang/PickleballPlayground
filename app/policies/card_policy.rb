class CardPolicy < ApplicationPolicy
  # Phase 1: delegate to DeckPolicy (which is itself partially stubbed).
  # Real rules in Phase 4.

  delegate :show?, :create?, :new?, :update?, :edit?, :destroy?, to: :deck_policy

  class Scope < ApplicationPolicy::Scope
    def resolve
      # TODO(phase-4): join through deck and merge DeckPolicy::Scope
      scope.none
    end
  end

  private

  def deck_policy = DeckPolicy.new(user, record.deck)
end
