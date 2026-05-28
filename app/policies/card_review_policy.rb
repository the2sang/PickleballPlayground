class CardReviewPolicy < ApplicationPolicy
  # Phase 1 stub. Phase 4 will add deck-access re-check per PITFALLS §Pitfall 8.

  def create?
    return false unless user.present? && record.user == user
    # TODO(phase-4): add `DeckPolicy.new(user, record.card.deck).show?` per PITFALLS §Pitfall 8.
    # DO NOT add yet — DeckPolicy#show? is personal-only in Phase 1, which would block
    # legitimate Phase 3 study of official decks.
    true
  end

  def show?    = create?
  def update?  = create?
  def destroy? = create?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present?
      scope.where(user_id: user.id)
    end
  end
end
