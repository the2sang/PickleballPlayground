require "rails_helper"

RSpec.describe "Decks::Studies", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, :personal, owner: user) }

  before { sign_in(user) }

  describe "GET /decks/:deck_id/study" do
    context "빈 덱 (카드 없음)" do
      it "세션 완료 화면을 즉시 렌더" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습 완료")
      end
    end

    context "due 없음 (카드 있지만 모두 미래 예정)" do
      before do
        card = create(:card, deck: deck)
        create(:card_review, :mature, user: user, card: card)
      end

      it "세션 완료 화면을 즉시 렌더" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습 완료")
      end
    end

    context "due 카드 있음" do
      before do
        card = create(:card, deck: deck)
        create(:card_review, :due, user: user, card: card)
      end

      it "학습 화면을 렌더 (완료 화면 아님)" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("오늘의 학습 완료")
      end
    end

    context "새 카드 있음 (CardReview 미생성)" do
      before { create(:card, deck: deck) }

      it "학습 화면을 렌더 (새 카드는 due로 취급)" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("오늘의 학습 완료")
      end

      it "이전/다음 문제 이동 컨트롤을 렌더한다" do
        get deck_study_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("quiz-nav")
        expect(response.body).to include("이전")
        expect(response.body).to include("다음")
      end
    end

    context "객관식 카드 학습 세션" do
      let!(:first_card) { create(:card, :multiple_choice, deck: deck, position: 1, front: "첫 문제", back: "정답 1") }
      let!(:second_card) { create(:card, :multiple_choice, deck: deck, position: 2, front: "둘째 문제", back: "정답 2") }

      it "다음 액션으로 이동한 뒤 이전 문제를 Turbo Stream으로 다시 열 수 있다" do
        get deck_study_path(deck)
        study_session = StudySession.find_by!(user: user, deck: deck, completed_at: nil)

        post card_reviews_path,
          params: {
            card_review: {
              card_id: first_card.id,
              deck_id: deck.id,
              study_session_id: study_session.id,
              rating: 4,
              selected_answer: first_card.back
            }
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("둘째 문제")
        expect(response.body).to include(deck_study_session_card_path(deck, study_session, first_card))
        expect(study_session.study_session_answers.find_by!(card: first_card).selected_answer).to eq(first_card.back)

        get deck_study_session_card_path(deck, study_session, first_card),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("첫 문제")
        expect(response.body).to match(/data-result=(&quot;|")correct/)
      end

      it "보기 텍스트를 쿠키 세션에 저장하지 않는다" do
        session[:study_session_options] = { "legacy" => { "1" => [ "긴 보기 텍스트" * 100 ] } }
        session[:study_session_selected_answers] = { "legacy" => { "1" => "이전 선택" } }

        get deck_study_path(deck)

        expect(response).to have_http_status(:ok)
        expect(request.session[:study_session_card_ids]).to be_present
        expect(request.session[:study_session_options]).to be_nil
        expect(request.session[:study_session_selected_answers]).to be_nil
      end
    end

    context "비인증 사용자" do
      before { delete session_path }

      it "로그인 페이지로 리다이렉트" do
        get deck_study_path(deck)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "min_stars 필터" do
      let!(:rated_card)   { create(:card, deck: deck) }
      let!(:unrated_card) { create(:card, deck: deck) }

      before do
        create(:user_card_rating, user: user, card: rated_card, difficulty: 4)
      end

      it "별점 4이상 카드만 학습 대상으로 포함" do
        get deck_study_path(deck, min_stars: 4)
        expect(response).to have_http_status(:ok)
      end

      it "별점 미해당 카드는 학습 대상 제외 (완료 화면 표시)" do
        get deck_study_path(deck, min_stars: 5)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 학습 완료")
      end
    end
  end

  describe "GET /decks/:deck_id (entry points)" do
    context "카드가 있는 덱" do
      before do
        create(:card, deck: deck)
        sign_in(user)
      end

      it "학습 시작 링크가 deck_study_path로 렌더된다" do
        get deck_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("decks/#{deck.id}/study")
      end

      it "학습 시작 링크 주변에 disabled 속성이 없다" do
        get deck_path(deck)
        # 학습 시작 버튼이 활성화 링크여야 하므로 disabled button이 없어야 함
        expect(response.body).not_to match(/<button[^>]*disabled[^>]*>학습 시작/)
      end
    end

    context "카드가 없는 덱" do
      before { sign_in(user) }

      it "학습 시작 버튼이 disabled로 렌더된다" do
        get deck_path(deck)
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/<button[^>]*disabled/)
        expect(response.body).to include("학습 시작")
      end

      it "카드를 먼저 추가하세요 안내 메시지가 표시된다" do
        get deck_path(deck)
        expect(response.body).to include("카드를 먼저 추가하세요")
      end
    end
  end
end
