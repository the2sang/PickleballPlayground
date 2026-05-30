class Cards::ImportsController < ApplicationController
  before_action :set_deck

  def new
    authorize @deck, :update?
  end

  def create
    authorize @deck, :update?
    mode = (params[:commit] == "저장" || params[:mode] == "save") ? :save : :preview
    @result = Flashcards::PasteImportService.call(
      text: params[:text].to_s,
      separator: decode_separator(params[:separator]),
      deck: @deck,
      mode: mode
    )

    if @result.success? && mode == :save
      redirect_to deck_path(@deck), notice: "#{@result.saved_count}장을 가져왔습니다."
    else
      respond_to do |format|
        format.turbo_stream do
          render :create, status: (@result.success? ? :ok : :unprocessable_entity)
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_deck
    @deck = Deck.where(owner: Current.user).find(params[:deck_id])
  end

  def decode_separator(raw)
    case raw
    when "tab", "\\t" then "\t"
    when "pipe"       then "|"
    when "dash"       then "=="
    when "comma"      then ","
    else raw.to_s
    end
  end
end
