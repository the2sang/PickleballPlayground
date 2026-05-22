class MemberRecordsController < ApplicationController
  before_action :set_member_record, only: %i[edit update destroy]

  def index
    authorize :member_record, :index?
    @member_records = policy_scope(MemberRecord).order(created_at: :desc)
  end

  def new
    authorize :member_record, :new?
    @member_record = MemberRecord.new
  end

  def create
    authorize :member_record, :create?
    @member_record = MemberRecord.new(member_record_params)
    if @member_record.save
      redirect_to member_records_path, notice: "회원이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @member_record
  end

  def update
    authorize @member_record
    if @member_record.update(member_record_params)
      redirect_to member_records_path, notice: "회원 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @member_record
    @member_record.destroy
    redirect_to member_records_path, notice: "회원이 삭제되었습니다."
  end

  def template
    authorize :member_record, :template?
    csv = MemberRecords::TemplateService.call
    send_data "\xEF\xBB\xBF#{csv}",
      filename: "회원명부_양식_#{Date.today.strftime('%Y%m%d')}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
  end

  def import
    authorize :member_record, :import?
    file = params[:import_file]
    return redirect_to member_records_path, alert: "파일을 선택해 주세요." unless file

    result = MemberRecords::ImportService.call(file: file)
    notice = "#{result.imported}명 등록, #{result.skipped}명 동의 미체크로 건너뜀"
    notice += " / 오류 #{result.errors.size}건" if result.errors.any?
    redirect_to member_records_path, notice: notice
  end

  private

  def set_member_record
    @member_record = MemberRecord.find(params[:id])
  end

  def member_record_params
    params.require(:member_record).permit(
      :name, :club_name, :gender, :birth_date, :phone,
      :pickleball_started_at, :club_joined_at, :address, :privacy_agreed
    )
  end
end
