Rails.application.routes.draw do
  # Devise のユーザー認証 + Omniauth コールバック
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  # root ページ
  root 'homes#index'

  # boardsリソース
  resources :boards

  # ログインユーザー自身のページ
  resource :user, only: [:show] do
    get 'google_connected', on: :member
  end
  
  # Gmailメール取得（任意ボタン用）
  get "/fetch_travel_emails", to: "google#fetch_travel_emails", as: "fetch_travel_emails"

  # LetterOpenerWeb（開発用メール確認）
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
