Rails.application.routes.draw do
  devise_for :users

  get '/auth/:provider/callback', to: 'google#callback'

  get "/auth/google_oauth2", to: "google#auth"
  get "/auth/google_oauth2/callback", to: "google#callback"

  
  root 'homes#index'
  resources :boards

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
