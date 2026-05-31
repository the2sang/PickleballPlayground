class Decks::UploadsController < ApplicationController
  def template
    authorize personal_deck, :create?
    template = Flashcards::ExcelTemplateService.call(kind: params[:kind])
    send_data template.data,
              filename: template.filename,
              type: template.content_type,
              disposition: "attachment"
  end

  def create
    authorize personal_deck, :create?
    result = Flashcards::ExcelImportService.call(file: params[:file], user: Current.user)

    if result.success?
      redirect_to decks_path, notice: "#{result.decks.size}개 덱, #{result.cards_count}장 카드를 업로드했습니다."
    else
      redirect_to decks_path, alert: result.errors.join(" ")
    end
  end

  private

  def personal_deck
    Deck.new(scope: :personal, owner: Current.user)
  end
end
