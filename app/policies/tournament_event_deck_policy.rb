# frozen_string_literal: true

class TournamentEventDeckPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end
end
