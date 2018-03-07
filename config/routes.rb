Rails.application.routes.draw do

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'work_plans#index'

  get '/sets/:set_name', to: 'work_orders#set_search'

  scope '/api/v1' do
    scope 'work_orders/:id' do
      post 'complete', to: 'work_orders#complete'
      post 'cancel', to: 'work_orders#cancel'
      get '', to: 'work_orders#get'
    end

    scope 'work_plans/:id' do
      get 'products/:product_id', to: 'products#show_product_inside_work_plan'
    end
  end

  resources :work_orders do
  	resources :build, controller: 'orders'
  end

  resources :work_plans do
    resources :build, controller: 'plan_wizard'
  end

end
