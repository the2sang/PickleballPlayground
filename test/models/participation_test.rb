require "test_helper"

class ParticipationTest < ActiveSupport::TestCase
  def setup
    @session = game_sessions(:open_public_session)
    @user    = users(:one)
  end

  test "valid member participation" do
    p = Participation.new(game_session: @session, user: @user)
    assert p.valid?
  end

  test "invalid without game_session" do
    p = Participation.new(user: @user)
    assert_not p.valid?
  end

  test "member cannot join same session twice" do
    Participation.create!(game_session: @session, user: @user, status: :confirmed)
    dup = Participation.new(game_session: @session, user: @user)
    assert_not dup.valid?
  end

  test "member can re-apply after cancellation" do
    Participation.create!(game_session: @session, user: @user, status: :cancelled)
    reapply = Participation.new(game_session: @session, user: @user, status: :confirmed)
    assert reapply.valid?, reapply.errors.full_messages.inspect
  end
end
