class Admin::DeckAdditionRequestsController < Admin::BaseController
  def update
    request = DeckAdditionRequest.find(params[:id])
    authorize request

    request.approve!(Current.user) if request.pending?
    redirect_to admin_root_path, notice: "덱 추가 승인요청을 허용했습니다."
  end
end
