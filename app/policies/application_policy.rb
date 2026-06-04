class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user   = user
    @record = record
  end

  def index?  = false
  def show?   = false
  def create? = false
  def new?    = create?
  def update? = false
  def edit?   = update?
  def destroy? = false

  private

  def site_admin?
    user.present? && user.admin?
  end

  def club_manager?(club)
    return false unless user.present?
    return true if user.admin?
    return true if club&.owner_id == user.id
    membership = user.club_memberships.find_by(club: club)
    membership.present? && membership.manager? && membership.approved?
  end

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
