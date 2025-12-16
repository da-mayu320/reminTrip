Rails.application.routes.draw do
  # Devise のユーザー認証 + Omniauth コールバック
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  # root ページ
  root 'homes#index'

  resources :travel_infos, only: [:index]
  
  # boardsリソース
  resources :boards

  # ログインユーザー自身のページ
  resource :user, only: [:show] do
    get 'google_connected', on: :member
  end
  
  # GoogleController 関連のルーティング
  scope :google do
    get 'auth', to: 'google#auth', as: :auth_google
    get 'callback', to: 'google#callback', as: :auth_google_callback
    get 'read_email', to: 'google#read_email'
  end

  # LetterOpenerWeb（開発用メール確認）
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
