Rails.application.routes.draw do

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'work_orders#index'

  resources :catalogues
  post '/catalogue', to: 'catalogues#create'

  resources :work_orders do
  	resources :build, controller: 'orders'
  	member do
	    post 'complete', to: 'work_orders#complete'
	    post 'cancel', to: 'work_orders#cancel'
  	end
  end

end
