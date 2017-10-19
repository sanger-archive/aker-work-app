Rails.application.routes.draw do

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'work_orders#index'

  scope '/api/v1' do
    post 'catalogue', to: 'catalogues#create'
    scope 'work_orders/:id' do
      post 'complete', to: 'work_orders#complete'
      post 'cancel', to: 'work_orders#cancel'
      get '', to: 'work_orders#get'

      get 'products/:product_id', to: 'products#show_product_inside_work_order'
      #resources :products, only: [:show] do
      #  get 'unit_price', to: 'products#unit_price'
      #end
    end
  end

  resources :work_orders do
  	resources :build, controller: 'orders'
  end

  #resources :products, only: [:show] do
  #  post 'unit_price', to: 'products#unit_price'
  #end

end
