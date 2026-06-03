require "test_helper"

class FlashMeetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(profile_completed_at: Time.current)
    sign_in_as(@user)
  end

  test "new form includes optional additional info textarea" do
    get new_flash_meetup_path

    assert_response :success
    assert_select "label[for='flash_meetup_additional_info']", text: "추가정보(선택)"
    assert_select "textarea[name='flash_meetup[additional_info]'][rows='5']", 1
  end

  test "create persists additional info" do
    assert_difference("FlashMeetup.count", 1) do
      post flash_meetups_path, params: {
        flash_meetup: {
          venue_name: "수지 실내코트",
          address: "용인시 수지구",
          scheduled_at: 2.days.from_now,
          ends_at: 2.days.from_now + 2.hours,
          max_participants: 8,
          additional_info: "주차는 지하 1층을 이용하세요.",
          gender_filter: "all_genders",
          level_filter: "all_levels"
        }
      }
    end

    meetup = FlashMeetup.order(:created_at).last
    assert_equal "주차는 지하 1층을 이용하세요.", meetup.additional_info
  end

  test "edit form includes existing additional info textarea" do
    meetup = flash_meetups(:one)
    meetup.update!(additional_info: "개인 패들 지참")

    get edit_flash_meetup_path(meetup)

    assert_response :success
    assert_select "textarea[name='flash_meetup[additional_info]'][rows='5']", text: /개인 패들 지참/
  end

  test "update persists additional info" do
    meetup = flash_meetups(:one)

    patch flash_meetup_path(meetup), params: {
      flash_meetup: {
        additional_info: "물과 실내화를 준비해 주세요."
      }
    }

    assert_redirected_to flash_meetup_path(meetup)
    assert_equal "물과 실내화를 준비해 주세요.", meetup.reload.additional_info
  end

  test "show displays additional info when present" do
    meetup = flash_meetups(:one)
    meetup.update!(additional_info: "코트 입장 전 데스크에서 예약자명을 확인해 주세요.")

    get flash_meetup_path(meetup)

    assert_response :success
    assert_select ".cl-info-row__label", text: "추가정보"
    assert_select ".cl-info-row__value", text: /코트 입장 전 데스크/
  end
end
