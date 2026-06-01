# frozen_string_literal: true

module Flashcards::StudyNavigation
  private

  def store_study_card_ids(study_session, card_ids)
    clear_legacy_cookie_payload

    store = session[:study_session_card_ids] || {}
    store[study_session.id.to_s] = Array(card_ids).map(&:to_i)
    session[:study_session_card_ids] = store
  end

  def study_card_ids(study_session)
    return [] unless study_session

    Array(session.dig(:study_session_card_ids, study_session.id.to_s)).map(&:to_i)
  end

  def study_options_for(study_session, deck, card)
    card.quiz_options(deck)
  end

  def clear_legacy_cookie_payload
    session.delete(:study_session_options)
    session.delete(:study_session_selected_answers)
  end
end
