Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'readmes#search_form'
  get '/readmes', to: 'readmes#search'
end
