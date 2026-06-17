module OpenSessionsHelper
  OPEN_SESSION_GENDER_LABELS = {
    "unspecified" => "미설정",
    "male" => "남성",
    "female" => "여성",
    "other" => "기타"
  }.freeze

  OPEN_SESSION_LEVEL_LABELS = {
    "beginner" => "초급",
    "beginner_intermediate" => "초중급",
    "intermediate" => "중급",
    "intermediate_advanced" => "중상급",
    "advanced" => "상급"
  }.freeze

  OPEN_SESSION_AGE_LABELS = {
    "teens" => "10대",
    "twenties" => "20대",
    "thirties" => "30대",
    "forties" => "40대",
    "fifties" => "50대",
    "sixties_plus" => "60대+"
  }.freeze

  def open_session_gender_icon(user)
    case user&.gender
    when "male" then "lucide:mars"
    when "female" then "lucide:venus"
    else "lucide:circle-user-round"
    end
  end

  def open_session_gender_label(user)
    OPEN_SESSION_GENDER_LABELS.fetch(user&.gender, "미설정")
  end

  def open_session_level_label(user)
    OPEN_SESSION_LEVEL_LABELS.fetch(user&.sport_level, "미설정")
  end

  def open_session_age_label(user)
    OPEN_SESSION_AGE_LABELS.fetch(user&.age_group, "미설정")
  end

  def open_session_participant_popup(participant)
    content_tag(:span, class: "oss-participant-popup", role: "tooltip") do
      safe_join([
        content_tag(:span, participant.display_name, class: "oss-participant-popup__name"),
        open_session_participant_popup_row("성별", open_session_gender_label(participant.user)),
        open_session_participant_popup_row("운동레벨", open_session_level_label(participant.user)),
        open_session_participant_popup_row("연령대", open_session_age_label(participant.user))
      ])
    end
  end

  def open_session_participant_popup_row(label, value)
    content_tag(:span, class: "oss-participant-popup__row") do
      safe_join([
        content_tag(:span, label, class: "oss-participant-popup__label"),
        content_tag(:strong, value)
      ])
    end
  end
end
