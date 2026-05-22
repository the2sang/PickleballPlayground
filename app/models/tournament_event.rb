class TournamentEvent < ApplicationRecord
  belongs_to :tournament
  has_many :tournament_teams, dependent: :destroy
  has_many :tournament_groups, dependent: :destroy
  has_many :matches, as: :matchable, dependent: :destroy

  enum :discipline, {
    mens_singles: 0, mens_doubles: 1,
    womens_singles: 2, womens_doubles: 3, mixed_doubles: 4
  }
  enum :scoring_format, { single_game: 0, best_of_3: 1 }, default: :single_game
  enum :status, { setup: 0, qualifying: 1, bracket: 2, completed: 3 }, default: :setup

  validates :discipline, presence: true
  validates :points_to_win, presence: true,
            numericality: { greater_than: 0 }
  validates :advances_per_group, numericality: { greater_than: 0 }

  SINGLES_DISCIPLINES = %w[mens_singles womens_singles].freeze

  def singles?
    SINGLES_DISCIPLINES.include?(discipline)
  end

  def max_team_size
    singles? ? 1 : 2
  end
end
