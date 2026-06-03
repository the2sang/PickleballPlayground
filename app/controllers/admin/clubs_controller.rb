module Admin
  class ClubsController < ApplicationController
    def index
      authorize [ :admin, Club.new ]
      @pending_clubs   = Club.pending.includes(:owner).order(:created_at)
      @approved_clubs  = Club.approved.includes(:owner).order(:name)
      @suspended_clubs = Club.suspended.includes(:owner).order(:name)
    end

    def show
      @club = Club.find(params[:id])
      authorize [ :admin, @club ]
      @memberships = @club.club_memberships.includes(:user)
    end

    def update
      @club = Club.find(params[:id])
      authorize [ :admin, @club ]
      updates = {}
      updates[:status] = params[:status] if params[:status].present?
      updates.merge!(club_params) if params[:club].present?

      @club.update!(updates)
      redirect_to admin_clubs_path, notice: "클럽 정보가 변경되었습니다."
    end

    private

    def club_params
      params.require(:club).permit(:hot_zone)
    end
  end
end
