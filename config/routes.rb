Rails.application.routes.draw do

  root 'work_orders#index'

  resources :shops

  resources :work_orders do
    resources :build, controller: 'orders'
  end
end
