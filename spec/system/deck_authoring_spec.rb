require "rails_helper"

RSpec.describe "Deck authoring", type: :system do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, scope: :personal, owner: user) }

  before do
    driven_by :rack_test
  end

  def sign_in_as(user)
    visit new_session_path
    fill_in "이메일", with: user.email_address
    fill_in "비밀번호", with: "password"
    click_button "로그인"
  end

  describe "인라인 카드 편집 (CARD-03)" do
    let!(:card) { create(:card, deck: deck) }

    it "행 클릭 → edit 링크 → 저장 → 덱 페이지" do
      sign_in_as(user)
      visit deck_path(deck)

      # 카드 행에 편집 링크가 있음
      expect(page).to have_link("편집")

      # 편집 링크 클릭 (rack_test에서는 Turbo Frame 동작 없음 — 전체 페이지 이동)
      click_link "편집"

      # 편집 폼 렌더링 확인
      expect(page).to have_field("card[front]")
      expect(page).to have_field("card[back]")

      # 수정 후 저장
      fill_in "card[front]", with: "수정된 앞면"
      fill_in "card[back]", with: "수정된 뒷면"
      click_button "저장"

      # 저장 후 덱 페이지로 이동
      expect(current_path).to eq(deck_path(deck))
    end
  end

  describe "카드 추가 폼 (CARD-01)" do
    it "폼으로 카드를 추가하면 덱 페이지에 표시된다" do
      sign_in_as(user)
      visit deck_path(deck)

      # 추가 폼이 있음
      expect(page).to have_field("card[front]")

      fill_in "card[front]", with: "새 앞면"
      fill_in "card[back]", with: "새 뒷면"
      click_button "저장하고 다음 (Cmd+Enter)"

      # rack_test에서는 Turbo Stream redirect 후 페이지 확인
      expect(current_path).to eq(deck_path(deck))
    end
  end
end
