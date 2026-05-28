class ClubNoticesController < ApplicationController
  before_action :set_club
  before_action :set_notice, only: %i[edit update destroy]

  def new
    @club_notice = @club.club_notices.build
    authorize @club_notice
  end

  def create
    @club_notice = @club.club_notices.build(club_notice_params)
    authorize @club_notice

    if @club_notice.save
      redirect_to manage_club_path(@club, anchor: "club-notices"), notice: "공지사항이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @club_notice
  end

  def update
    authorize @club_notice

    if @club_notice.update(club_notice_params)
      redirect_to manage_club_path(@club, anchor: "club-notices"), notice: "공지사항이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @club_notice
    @club_notice.destroy!
    redirect_to manage_club_path(@club, anchor: "club-notices"), notice: "공지사항이 삭제되었습니다."
  end

  private

  def set_club = @club = Club.find(params[:club_id])

  def set_notice = @club_notice = @club.club_notices.find(params[:id])

  def club_notice_params
    params.require(:club_notice).permit(:title, :body, :published_at)
  end
end
