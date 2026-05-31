class DeckBookmarkPolicy < ApplicationPolicy
  def create?
    user.present? && DeckPolicy.new(user, record.deck).show?
  end

  def destroy?
    user.present? && record.user == user
  end
end
