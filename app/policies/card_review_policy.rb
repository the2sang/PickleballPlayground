class CardReviewPolicy < ApplicationPolicy
  def create?
    return false unless user.present? && record.user == user
    DeckPolicy.new(user, record.card.deck).show?
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
