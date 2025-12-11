Rails.application.routes.draw do
  devise_for :users

  get '/auth/:provider/callback', to: 'google#callback'

  get "/auth/google_oauth2/callback", to: "google#callback"
  get "/google/auth", to: "google#auth", as: :google_auth

  
  root 'homes#index'
  resources :boards

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
