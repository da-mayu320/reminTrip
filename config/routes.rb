Rails.application.routes.draw do
  devise_for :users
  
  root 'homes#index'
  resources :boards

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
