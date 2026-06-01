class AddSelectedAnswerToStudySessionAnswers < ActiveRecord::Migration[8.1]
  def change
    add_column :study_session_answers, :selected_answer, :text
  end
end
