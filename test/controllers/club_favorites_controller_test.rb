require "test_helper"

class ClubFavoritesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @club           = clubs(:approved_club)
    @member         = users(:two)    # has approved ClubMembership for approved_club
    @non_member     = users(:three)  # no ClubMembership record at all
    @pending_member = users(:one)    # has pending ClubMembership for approved_club
    ClubFavorite.where(user: @member, club: @club).delete_all  # remove fixture conflict
  end

  test "approved member can favorite a club" do
    sign_in_as @member
    assert_difference "ClubFavorite.count", 1 do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :ok
  end

  test "non-member cannot favorite a club" do
    sign_in_as @non_member
    assert_no_difference "ClubFavorite.count" do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :redirect
  end

  test "unauthenticated user cannot favorite" do
    assert_no_difference "ClubFavorite.count" do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :redirect
  end

  test "member can unfavorite a club" do
    fav = ClubFavorite.create!(user: @member, club: @club)
    sign_in_as @member
    assert_difference "ClubFavorite.count", -1 do
      delete club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :ok
  end

  test "pending member can also favorite a club" do
    sign_in_as @pending_member  # users(:one) has pending membership
    assert_difference "ClubFavorite.count", 1 do
      post club_favorite_path(@club), as: :turbo_stream
    end
    assert_response :ok
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end
