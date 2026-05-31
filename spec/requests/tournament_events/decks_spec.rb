# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TournamentEvents::Decks", type: :request do
  let(:club)     { create(:club) }
  let(:manager)  { create(:user) }
  let(:other)    { create(:user) }
  let(:tournament) { create(:tournament, club: club) }
  let(:event)    { create(:tournament_event, tournament: tournament) }
  let!(:membership) do
    create(:club_membership, club: club, user: manager, role: :manager, status: :approved)
  end

  describe "GET /tournament_events/:id/decks/edit" do
    context "club manager" do
      before { sign_in(manager) }

      it "200 OK" do
        get edit_tournament_event_decks_path(event)
        expect(response).to have_http_status(:ok)
      end

      it "후보 덱 목록을 렌더한다" do
        official_deck = create(:deck, :official)
        get edit_tournament_event_decks_path(event)
        expect(response.body).to include(official_deck.title)
      end

      it "다른 클럽 club 덱은 후보에 없다" do
        other_club  = create(:club)
        other_deck  = create(:deck, :club, owner: other_club)
        get edit_tournament_event_decks_path(event)
        expect(response.body).not_to include(other_deck.title)
      end
    end

    context "비매니저" do
      before { sign_in(other) }

      it "403 리다이렉트" do
        get edit_tournament_event_decks_path(event)
        expect(response).to redirect_to(root_path)
      end
    end

    context "비인증" do
      it "로그인으로 리다이렉트" do
        get edit_tournament_event_decks_path(event)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "PUT /tournament_events/:id/decks" do
    let!(:official_deck) { create(:deck, :official) }

    context "club manager" do
      before { sign_in(manager) }

      it "덱 매핑을 저장하고 종목 페이지로 리다이렉트" do
        put tournament_event_decks_path(event),
            params: { deck_ids: [ official_deck.id ] }
        expect(response).to redirect_to(tournament_event_path(event))
        expect(TournamentEventDeck.where(tournament_event: event).count).to eq(1)
      end

      it "position 순서가 올바르다" do
        deck2 = create(:deck, :official, title: "덱 B")
        put tournament_event_decks_path(event),
            params: { deck_ids: [ official_deck.id, deck2.id ] }
        teds = TournamentEventDeck.where(tournament_event: event).order(:position)
        expect(teds.map(&:deck_id)).to eq([ official_deck.id, deck2.id ])
        expect(teds.map(&:position)).to eq([ 0, 1 ])
      end

      it "기존 매핑을 교체한다" do
        old_deck = create(:deck, :official)
        create(:tournament_event_deck, tournament_event: event, deck: old_deck, position: 0)

        put tournament_event_decks_path(event),
            params: { deck_ids: [ official_deck.id ] }

        expect(TournamentEventDeck.where(tournament_event: event, deck: old_deck)).not_to exist
        expect(TournamentEventDeck.where(tournament_event: event, deck: official_deck)).to exist
      end

      it "다른 클럽 덱으로 저장 불가 (후보에 없음 — 뷰 단 방어)" do
        other_club = create(:club)
        other_deck = create(:deck, :club, owner: other_club)
        put tournament_event_decks_path(event),
            params: { deck_ids: [ other_deck.id ] }
        expect(response).to redirect_to(tournament_event_path(event))
      end
    end

    context "비매니저" do
      before { sign_in(other) }

      it "403 리다이렉트" do
        put tournament_event_decks_path(event),
            params: { deck_ids: [ official_deck.id ] }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
