Rails.application.routes.draw do
  root "top#index"

  resources :users, only: %i[new create]
  resources :cost_lists, only: %i[new create]

  get "top/index"

  get "login", to: "user_sessions#new"
  post "login", to: "user_sessions#create"

  delete "logout", to: "user_sessions#destroy"

  get "up" => "rails/health#show", as: :rails_health_check
end
