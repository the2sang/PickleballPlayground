class DeckPolicy < ApplicationPolicy
  # ── Visibility ──────────────────────────────────────────────────────────

  def show?
    return true if record.official?
    return true if site_admin?
    return false unless user.present?
    return club_member? if record.club?
    personal_owner?
  end

  # ── Creation ─────────────────────────────────────────────────────────────

  def create?
    return false unless user.present?
    return site_admin?  if record.official?
    return club_member? if record.club?
    true # personal
  end

  def new? = create?

  # ── Mutation ─────────────────────────────────────────────────────────────

  def update?
    return true  if site_admin?
    return false unless user.present?
    return club_manager? if record.club?
    personal_owner?
  end

  def edit? = update?

  def destroy?
    return true  if site_admin?
    return false unless user.present?
    return club_manager? if record.club?
    personal_owner?
  end

  # ── Domain actions ────────────────────────────────────────────────────────

  def fork?
    return false unless user.present?
    return false if record.personal?
    return true  if site_admin?
    return club_member? if record.club?
    true # official
  end

  def feature?
    return false unless user.present?
    return false if record.personal?
    return true  if site_admin?
    return false unless record.club?
    club_manager?
  end

  def moderate?
    return false unless user.present?
    return false if record.personal?
    return true  if site_admin?
    return false unless record.club?
    club_manager?
  end

  # ── Scope ─────────────────────────────────────────────────────────────────

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if admin?

      conditions = [ "decks.scope = #{Deck.scopes[:official]}" ]

      if user.present?
        conditions << "decks.scope = #{Deck.scopes[:personal]} AND decks.owner_type = 'User' AND decks.owner_id = #{user.id}"

        approved_club_ids = user.club_memberships.approved.pluck(:club_id)
        if approved_club_ids.any?
          ids = approved_club_ids.join(",")
          conditions << "decks.scope = #{Deck.scopes[:club]} AND decks.owner_type = 'Club' AND decks.owner_id IN (#{ids})"
        end
      end

      scope.where(conditions.map { |c| "(#{c})" }.join(" OR "))
    end

    private

    def admin?
      user.present? && user.admin?
    end
  end

  private

  def personal_owner?
    return false unless user.present?
    record.personal? && record.owner == user
  end

  def club_member?
    return false unless record.club?
    club = record.owner
    return true if club.owner_id == user.id
    user.club_memberships.approved.exists?(club_id: club.id)
  end

  def club_manager?
    return false unless record.club?
    super(record.owner)
  end
end
