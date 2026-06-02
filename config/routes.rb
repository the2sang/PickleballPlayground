Rails.application.routes.draw do
  post "telegram/webhook", to: "telegram/webhooks#create", as: :telegram_webhook

  resource :session, only: %i[ new create destroy ]
  get "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  get "/auth/naver/callback",         to: "omniauth_callbacks#naver"
  get "/auth/failure",                to: "omniauth_callbacks#failure"
  resources :passwords, param: :token, only: %i[ new create edit update ]
  resource :registration, only: %i[ new create ]
  resource :profile, only: %i[ edit update ] do
    collection { get :dupr_lookup }
  end
  resource :account, only: %i[ edit update ]

  resource :focus, only: %i[show] do
    resource :settings, controller: "focus/settings", only: %i[show update]
  end

  resources :work_plans do
    member { get :hwpx }
  end
  resources :work_journals
  resources :manpower_records, only: %i[index create update destroy]
  resources :memos
  resources :posts
  resources :stock_infos, only: %i[index show destroy]

  resources :clubs do
    resource :favorite, only: %i[create destroy], controller: "club_favorites"
    member { get :manage }
    resources :club_memberships, only: %i[index create update destroy], shallow: false
    resources :guest_applications, only: %i[new create], path: "guest"
    resources :tournaments, only: %i[index new create]
    resources :club_notices, except: %i[index show]
  end

  resources :decks do
    resources :cards, only: %i[create edit update destroy]
    namespace :cards do
      resource :imports, only: %i[new create]
    end
    resource  :study,          only: %i[show], module: :decks
    resource  :browse,         only: %i[show], module: :decks
    resource  :flip,           only: %i[show], module: :decks
    resources :card_ratings,   only: %i[create], module: :decks
    resources :card_bookmarks, only: %i[create destroy], module: :decks, param: :card_id
    resources :study_sessions, only: %i[show], module: :decks do
      get "cards/:card_id", to: "study_cards#show", as: :card
    end
    resource  :bookmark,       only: %i[create destroy], module: :decks
    resource  :fork,           only: %i[create], module: :decks
    resource  :feature,        only: %i[create destroy], module: :decks
  end
  get  "deck_uploads/templates/:kind", to: "decks/uploads#template", as: :deck_upload_template
  post "deck_uploads",                 to: "decks/uploads#create",   as: :deck_uploads
  resources :deck_addition_requests, only: %i[create]

  resources :card_reviews, only: %i[create]
  get "/study", to: "study#show", as: :study

  resources :tournaments, only: %i[show edit update destroy] do
    member { patch :advance_status }
    resources :tournament_events, only: %i[new create]
  end

  resources :tournament_events, only: %i[show edit update destroy] do
    resource :decks, only: %i[edit update], module: :tournament_events
    member do
      post :generate_groups
      post :generate_bracket
    end
    resources :tournament_teams,  only: %i[index new create]
    resources :tournament_groups, only: %i[index new create]
  end

  resources :tournament_teams, only: %i[show edit update destroy] do
    resources :tournament_team_members, only: %i[create destroy]
  end

  resources :tournament_groups, only: %i[show edit update destroy] do
    resources :tournament_group_teams, only: %i[create destroy]
  end

  resources :matches, only: %i[show edit update] do
    member { post :advance_winner }
  end
  resources :game_sessions, only: %i[index show new create edit update destroy] do
    resource :code_dash_participation, only: :create
    resources :participations, only: %i[new create destroy], shallow: false
    resources :comments, only: %i[create destroy], shallow: false
  end
  resources :flash_meetups, only: %i[index show new create edit update destroy] do
    resources :flash_meetup_participations, only: %i[create destroy], shallow: false
    resources :comments, only: %i[create destroy], shallow: false
  end
  namespace :my do
    resources :participations, only: %i[index destroy]
  end

  namespace :admin do
    root "dashboards#index"
    resource :site_setting, only: :update
    resources :users, only: %i[index show update]
    resources :sessions, only: %i[index]
    resources :groups
    resources :clubs, only: %i[index show update]
    resources :deck_addition_requests, only: %i[update]
    get  "data_management",                         to: "data_management#show",            as: :data_management
    post "data_management/execute",                 to: "data_management#execute",         as: :data_management_execute
    post "data_management/backups",                 to: "data_management#create_backup",   as: :data_management_backups
    post "data_management/backups/restore",         to: "data_management#restore_backup",  as: :data_management_backup_restore
    get  "data_management/backups/:id/*file",       to: "data_management#download_backup", as: :data_management_backup, format: false
  end

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check

  resources :member_records, except: %i[show] do
    collection do
      get  :template
      post :import
    end
  end

  get "puzzle", to: "pages#puzzle"
  root "clubs#index"
end
