Rails.application.routes.draw do
  root "top#index"

  get "terms", to: "static_pages#terms"
  get "privacy", to: "static_pages#privacy"
  get "guide", to: "static_pages#guide"

  resources :users, only: %i[new create]
  resources :password_resets, only: %i[new create edit update]

  resource :mypage, only: %i[show edit update]

  resources :cost_lists, only: %i[new create show edit update destroy] do
    member do
      patch :update_memo
      patch :update_title
    end

    collection do
      get :result
      post :save_session
      get :compare
    end

    resources :cost_items, only: [] do
      member do
        patch :update_status
      end
    end
  end

  get "top/index"

  get "login", to: "user_sessions#new"
  post "login", to: "user_sessions#create"

  delete "logout", to: "user_sessions#destroy"

  post "oauth/google", to: "google_oauths#oauth", as: :google_oauth
  get "oauth/google/callback", to: "google_oauths#callback", as: :google_oauth_callback

  get "up" => "rails/health#show", as: :rails_health_check
end
