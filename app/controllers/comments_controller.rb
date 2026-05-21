class CommentsController < ApplicationController
  before_action :set_commentable

  def create
    @comment = @commentable.comments.build(comment_params)
    @comment.user = Current.user
    if @comment.save
      redirect_to @commentable, notice: "댓글이 등록되었습니다."
    else
      redirect_to @commentable, alert: @comment.errors.full_messages.first
    end
  end

  def destroy
    @comment = @commentable.comments.find(params[:id])
    unless @comment.user == Current.user
      redirect_to @commentable, alert: "권한이 없습니다." and return
    end
    @comment.destroy
    redirect_to @commentable
  end

  private

  def set_commentable
    if params[:game_session_id]
      @commentable = GameSession.find(params[:game_session_id])
    elsif params[:flash_meetup_id]
      @commentable = FlashMeetup.find(params[:flash_meetup_id])
    end
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end
end
