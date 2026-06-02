require "rails_helper"
require "yaml"

# Tests the idempotent YAML-driven seed loader at db/seeds/flashcards.rb.
#
# We don't execute db/seeds.rb wholesale (it would try to re-create the demo
# users + clubs + etc., colliding with anything the test DB already has).
# Instead we ensure the required admin user exists, then `load` the flashcards
# loader file directly. The loader is wrapped in
# ActiveRecord::Base.transaction { ... } so failure leaves no partial state.
RSpec.describe "Flashcards seed loader" do
  let(:admin) do
    User.find_or_create_by!(email_address: "admin@example.com") do |u|
      u.nickname    = "seed_admin_#{SecureRandom.hex(3)}"
      u.password    = "password"
      u.role        = :admin
      u.sport_level = :beginner
      u.age_group   = :twenties
      u.gender      = :unspecified
    end
  end

  before { admin } # ensure admin exists before loader runs

  def run_loader
    load Rails.root.join("db/seeds/flashcards.rb")
  end

  it "creates exactly 8 official decks" do
    run_loader
    expect(Deck.official.count).to eq(8)
  end

  it "creates the AI usage terms subjective official deck with 30 cards" do
    run_loader

    deck = Deck.official.find_by!(title: "개발자가 알아야 할 AI 활용 용어 30선")
    expect(deck.description).to include("주관식")
    expect(deck.cards.count).to eq(30)
    expect(deck.cards.first.back).to eq("Prompt (프롬프트)")
  end

  it "creates the economy current affairs short-answer official deck with 20 cards" do
    run_loader

    deck = Deck.official.find_by!(title: "직장인이 알아야 할 경제 시사 상식 20선")
    expect(deck.description).to include("단답형 주관식")
    expect(deck.cards.count).to eq(20)
    expect(deck.cards.first.back).to eq("기준금리")
  end

  it "creates the Software After AI official deck with subjective and multiple-choice cards" do
    run_loader

    deck = Deck.official.find_by!(title: "Software After AI")
    expect(deck).to be_science_technology
    expect(deck.cards.count).to eq(20)
    expect(deck.cards.basic.count).to be > 0
    expect(deck.cards.multiple_choice.count).to be > 0
    expect(deck.cards.multiple_choice.first.answer_choices.size).to eq(3)
  end

  it "is idempotent — running twice does not create duplicate decks or cards" do
    run_loader
    first_deck_count = Deck.official.count
    first_card_count = Card.joins(:deck).where(decks: { scope: :official }).count

    run_loader

    expect(Deck.official.count).to eq(first_deck_count)
    expect(Card.joins(:deck).where(decks: { scope: :official }).count).to eq(first_card_count)
  end

  it "honors declared expected_card_count for each official deck" do
    run_loader
    yaml = YAML.safe_load_file(Rails.root.join("db/seeds/flashcards.yml"), aliases: false, permitted_classes: [])

    yaml.fetch("official_decks").each do |entry|
      deck     = Deck.official.find_by!(title: entry.fetch("title"))
      expected = entry.fetch("expected_card_count")

      expect(deck.cards.count).to eq(expected),
        "#{entry['title']} expected #{expected}, got #{deck.cards.count}"
    end
  end

  it "assigns the declared representative category to each official deck" do
    run_loader
    yaml = YAML.safe_load_file(Rails.root.join("db/seeds/flashcards.yml"), aliases: false, permitted_classes: [])

    yaml.fetch("official_decks").each do |entry|
      deck = Deck.official.find_by!(title: entry.fetch("title"))
      expect(deck.category_before_type_cast).to eq(entry.fetch("category")),
        "#{entry['title']} expected category #{entry['category']}, got #{deck.category_before_type_cast}"
    end
  end

  it "syncs deck category when YAML changes" do
    run_loader
    deck = Deck.official.find_by!(title: "피클볼 기본 룰 30선")
    deck.update_column(:category, Deck.categories[:other])

    run_loader

    expect(deck.reload).to be_sports_arts
  end

  it "loads cards with positions 1..n contiguous per deck (no gaps)" do
    run_loader
    Deck.official.find_each do |deck|
      positions = deck.cards.order(:position).pluck(:position)
      expected  = (1..positions.size).to_a
      expect(positions).to eq(expected),
        "#{deck.title} positions #{positions.inspect} != contiguous #{expected.inspect}"
    end
  end

  it "loads cards with the draft: true flag intact (they still seed)" do
    run_loader
    # Wave 5.1 outcome: cards remain in draft state but ARE seeded — the loader's
    # ⚠ draft warnings are advisory, not blocking. The model has no `draft` column;
    # the flag lives only in YAML, used to emit warnings. Asserting cards exist
    # (count gate above) implicitly verifies they seed despite draft: true.
    expect(Card.joins(:deck).where(decks: { scope: :official }).count).to be > 0
  end

  it "syncs deck description when YAML changes" do
    run_loader
    deck = Deck.official.first
    deck.update_column(:description, "stale description")

    run_loader

    yaml          = YAML.safe_load_file(Rails.root.join("db/seeds/flashcards.yml"), aliases: false, permitted_classes: [])
    expected_desc = yaml.fetch("official_decks").find { |d| d["title"] == deck.title }.fetch("description")
    expect(deck.reload.description).to eq(expected_desc)
  end
end
