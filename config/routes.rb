Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "up" => "rails/health#show", as: :rails_health_check

  # 映画一覧表示
  get '/movies', to: 'movies#index'

  # 座席一覧表示
  resources :sheets, only: [:index]

  # 管理画面（admin namespace）
  namespace :admin do
    resources :movies, only: [:index, :new, :create, :edit, :update, :destroy]
  end
  # Defines the root path route ("/")
  # root "posts#index"
end
