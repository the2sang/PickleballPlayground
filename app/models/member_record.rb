class MemberRecord < ApplicationRecord
  CLUBS = %w[마북 S&D 구갈 처인 단국대 파라 시니어].freeze
  GENDERS = %w[여 남 기타].freeze

  EXCEL_HEADERS = [
    "이름", "소속클럽", "성별", "생년월일(yyyy-mm-dd)",
    "연락처", "피클볼시작일(yyyy-mm)", "클럽가입시기(yyyy-mm)",
    "주소", "개인정보수집동의(Y/N)"
  ].freeze

  validates :name, presence: true
  validates :club_name, inclusion: { in: CLUBS, message: "올바른 클럽을 선택하세요" }, allow_blank: true
  validates :gender, inclusion: { in: GENDERS, message: "올바른 성별을 선택하세요" }, allow_blank: true
  validates :privacy_agreed, acceptance: true
end
