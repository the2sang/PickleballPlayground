class WorkJournalsController < ApplicationController
  before_action :set_work_journal, only: %i[show edit update destroy]

  rescue_from Pundit::NotAuthorizedError do
    redirect_to work_journals_path, alert: "권한이 없습니다."
  end

  def index
    authorize WorkJournal
    validate_month_params
    @selected_date = parse_date_param(raise_on_invalid: true)
    @work_journals = Current.session.user.work_journals
    @work_journals = @work_journals.for_date(@selected_date) if @selected_date.present?
    @work_journals = @work_journals.recent
  rescue Date::Error
    redirect_to work_journals_path
  end

  def show
    authorize @work_journal
  end

  def new
    authorize WorkJournal
    @date = parse_date_param || Date.current
    @work_journal = WorkJournal.new(default_work_journal_attributes(work_date: @date))
  end

  def create
    attrs = default_work_journal_attributes.merge(work_journal_params)
    @work_journal = Current.session.user.work_journals.new(attrs)
    @work_journal.sequence_number = next_sequence(
      Current.session.user,
      @work_journal.work_date,
      @work_journal.entry_type
    )
    if @work_journal.save
      respond_to do |format|
        format.html { redirect_to_saved_journal }
        format.turbo_stream { redirect_to_saved_journal }
      end
    else
      @date = @work_journal.work_date || Date.current
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @work_journal
  end

  def update
    authorize @work_journal
    if @work_journal.update(work_journal_params)
      redirect_to work_journal_path(@work_journal), notice: "업무일지가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @work_journal
    date = @work_journal.work_date
    @work_journal.destroy
    redirect_to new_work_journal_path(date: date), notice: "항목이 삭제되었습니다."
  end

  private

  def set_work_journal
    @work_journal = WorkJournal.find(params[:id])
  end

  def validate_month_params
    return if params[:year].blank? && params[:month].blank?

    Date.new(params[:year].to_i, params[:month].to_i, 1)
  end

  def parse_date_param(raise_on_invalid: false)
    return if params[:date].blank?

    Date.parse(params[:date])
  rescue Date::Error
    raise if raise_on_invalid

    nil
  end

  def next_sequence(user, date, type)
    return 1 if date.blank? || type.blank?

    user.work_journals.where(work_date: date, entry_type: type).count + 1
  end

  def default_work_journal_attributes(work_date: Date.current)
    {
      work_date: work_date,
      content_format: "markdown",
      category: :task,
      status: :in_progress,
      progress: 0,
      entry_type: :result
    }
  end

  def redirect_to_saved_journal
    redirect_to work_journals_path(anchor: helpers.dom_id(@work_journal)),
                notice: "오늘하루 일지가 저장되었습니다.",
                status: :see_other
  end

  def work_journal_params
    params.require(:work_journal).permit(
      :title, :content, :content_format,
      :category, :status, :progress, :work_date, :entry_type
    )
  end
end
