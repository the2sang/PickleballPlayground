require "test_helper"

class ClubFavoriteTest < ActiveSupport::TestCase
  def setup
    @user  = users(:one)
    @club  = clubs(:approved_club)
  end

  test "valid with user and club" do
    fav = ClubFavorite.new(user: @user, club: @club)
    assert fav.valid?
  end

  test "invalid without user" do
    fav = ClubFavorite.new(club: @club)
    assert_not fav.valid?
  end

  test "invalid without club" do
    fav = ClubFavorite.new(user: @user)
    assert_not fav.valid?
  end

  test "user cannot favorite same club twice" do
    ClubFavorite.create!(user: @user, club: @club)
    dup = ClubFavorite.new(user: @user, club: @club)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "이미 즐겨찾기한 동호회입니다."
  end
end
