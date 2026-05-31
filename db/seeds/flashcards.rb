# 낱말카드 v1 — 공식 덱 시드 로더 (idempotent).
#
# 호출 흐름: db/seeds.rb 가 이 파일을 load 합니다 (require 아님 — 재실행 시 cleanly 재평가).
# 데이터: db/seeds/flashcards.yml (HUMAN-AUTHORED).
# 게이트: 각 덱은 expected_card_count 만큼 카드가 있어야 합니다 (Wave 5.1 후);
#         부족하면 ⚠ 경고만 출력하고 시드를 중단하지 않습니다.
# draft: true 가 남아 있는 카드는 ⚠ 경고로 표시 (검토 미완료 신호 — 블로킹 아님).
require "yaml"

data = YAML.safe_load_file(
  Rails.root.join("db/seeds/flashcards.yml"),
  aliases:          false,
  permitted_classes: []
)

# 방어적 재조회 — seeds.rb의 user_admin 로컬 변수를 신뢰하지 않음.
# admin 사용자는 official 덱의 owner가 아니지만 (official → owner: nil) 시드 순서
# 의존성을 명시적으로 강제합니다.
User.find_by!(email_address: "admin@example.com")

ActiveRecord::Base.transaction do
  Array(data["official_decks"]).each do |deck_attrs|
    title          = deck_attrs.fetch("title")
    expected_count = deck_attrs.fetch("expected_card_count")
    category       = Deck.category_filter_value(deck_attrs["category"]) || Deck.categories[:other]

    deck = Deck.find_or_create_by!(scope: :official, title: title) do |d|
      d.description = deck_attrs["description"]
      d.category    = category
      d.owner       = nil
    end
    deck.update!(description: deck_attrs["description"]) if deck.description != deck_attrs["description"]
    deck.update!(category: category) if deck.category_before_type_cast != category

    Array(deck_attrs["cards"]).each_with_index do |card_attrs, idx|
      card = deck.cards.find_or_initialize_by(front: card_attrs.fetch("front"))
      card.back     = card_attrs.fetch("back")
      card.hint     = card_attrs["hint"]
      card.tags     = card_attrs["tags"]
      card.position = idx + 1
      card.save!

      # 검토 미완료 카드(draft: true) 경고 — 블로킹 아님.
      if card_attrs["draft"] == true
        warn "⚠ draft (not yet reviewed): '#{title}' / position #{idx + 1} — #{card_attrs.fetch('front').to_s[0, 40]}"
      end
    end

    actual = deck.cards.count
    if actual != expected_count
      warn "⚠ 낱말카드 seed: '#{title}' expects #{expected_count} cards but has #{actual} — fill db/seeds/flashcards.yml"
    end
  end
end

official_count = Deck.official.count
total_cards    = Card.joins(:deck).where(decks: { scope: :official }).count
puts "   #{official_count} official decks, #{total_cards} official cards"
