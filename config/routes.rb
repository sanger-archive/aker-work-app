Rails.application.routes.draw do

  devise_for :users, controllers: { sessions: 'users/sessions' }

  root 'work_orders#index'

  resources :catalogues
  post '/catalogue', to: 'catalogues#create'

  resources :work_orders do
    resources :build, controller: 'orders'
  end

end
