Rails.application.routes.draw do

  root 'work_orders#index'
  post '/catalogue', to: 'catalogues#create'

  resources :shops

  resources :work_orders do
    resources :build, controller: 'orders'
  end

end
