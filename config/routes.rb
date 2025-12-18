Rails.application.routes.draw do
  # Devise のユーザー認証 + Omniauth コールバック
  devise_for :users,
    controllers: {
      omniauth_callbacks: 'users/omniauth_callbacks'
    },
    skip: [:registrations]
  
  devise_scope :user do
    delete 'users/sign_out', to: 'devise/sessions#destroy', as: :destroy_user_session
  end

  # root ページ
  root 'homes#index'

  resources :travel_infos do
    post :fetch_from_gmail, on: :collection
  end
  
  # boardsリソース
  resources :boards

  # ログインユーザー自身のページ
  resource :user, only: [:show] do
    get 'google_connected', on: :member
  end

  # LetterOpenerWeb（開発用メール確認）
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
