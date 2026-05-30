class StudySessionPolicy < ApplicationPolicy
  def show?
    record.user == user
  end
end
