class Match < ApplicationRecord
  belongs_to :matchable, polymorphic: true
  belongs_to :home_team, class_name: "TournamentTeam", optional: true
  belongs_to :away_team, class_name: "TournamentTeam", optional: true
  belongs_to :winner,    class_name: "TournamentTeam", optional: true
  belongs_to :next_match, class_name: "Match", optional: true
  has_many :match_sets, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2, locked: 3 }, default: :pending

  def bye?
    home_team.nil? || away_team.nil?
  end

  def next_round_started?
    next_match.present? && next_match.status.in?(%w[in_progress completed locked])
  end
end
