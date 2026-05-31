class DeckAdditionRequestsController < ApplicationController
  def create
    request = Current.user.deck_addition_requests.build(
      requested_limit: Current.user.personal_deck_limit + 1
    )
    authorize request

    if Current.user.can_create_personal_decks?
      redirect_to decks_path, notice: "아직 덱을 추가할 수 있습니다."
    elsif Current.user.pending_deck_addition_request.present?
      redirect_to decks_path, alert: "이미 처리 대기 중인 덱 추가 승인요청이 있습니다."
    elsif request.save
      redirect_to decks_path, notice: "덱 추가 승인요청이 관리자에게 접수되었습니다."
    else
      redirect_to decks_path, alert: request.errors.full_messages.to_sentence
    end
  end
end
