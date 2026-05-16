class ClubFavorite < ApplicationRecord
  belongs_to :user
  belongs_to :club

  validates :user_id, uniqueness: { scope: :club_id, message: "이미 즐겨찾기한 동호회입니다." }
end
