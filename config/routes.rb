Rails.application.routes.draw do

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'work_orders#index'

  get '/sets/:set_name', to: 'work_orders#set_search'
  get '/products/:product_id', to: 'products#get_product_description'

  scope '/api/v1' do
    post 'catalogue', to: 'catalogues#create'
    scope 'work_orders/:id' do
      post 'complete', to: 'work_orders#complete'
      post 'cancel', to: 'work_orders#cancel'
      get '', to: 'work_orders#get'

      get 'products/:product_id', to: 'products#show_product_inside_work_order'
    end
  end

  resources :work_orders do
  	resources :build, controller: 'orders'
  end

end
