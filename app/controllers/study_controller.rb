class StudyController < ApplicationController
  def show
    skip_authorization
    @due_cards = Flashcards::GlobalStudyQueueQuery.new(user: Current.user).call
    if @due_cards.empty?
      render :complete
    end
  end
end
