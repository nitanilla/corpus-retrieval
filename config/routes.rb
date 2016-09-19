require 'sidekiq/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  mount Sidekiq::Web => '/sidekiq'
  root to: 'readmes#index', as: :readmes
  resources :readmes, only: [] do
    get :download
    post :search, on: :collection
  end
end
