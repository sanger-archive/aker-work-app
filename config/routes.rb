Rails.application.routes.draw do

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'work_plans#index'

  get '/sets/:set_name', to: 'work_orders#set_search'

  scope '/api/v1' do
    scope 'work_orders/:id' do
      post 'create_editable_set', to: 'work_orders#create_editable_set', as: :create_editable_set
      get '', to: 'work_orders#get'
    end

    scope 'work_plans/:id' do
      get 'products/:product_id', to: 'products#show_product_inside_work_plan'
      get 'products/unit_price/:module_ids', to: 'products#modules_unit_price'
    end

  end

  namespace :api do
    namespace :v1 do
      jsonapi_resources :jobs do
        put 'start', to: 'jobs#start'
        put 'complete', to: 'jobs#complete'
        put 'cancel', to: 'jobs#cancel'
      end
    end
  end

  resources :work_orders

  resources :work_plans do
    resources :build, controller: 'plan_wizard'
  end
end
