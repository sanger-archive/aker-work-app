Rails.application.routes.draw do

  root 'work_orders#index'

  resources :catalogues
  post '/catalogue', to: 'catalogues#create'

  resources :work_orders do
    post 'complete', to: 'work_orders#complete'
    post 'cancel', to: 'work_orders#cancel'        
    resources :build, controller: 'orders'
  end

end
