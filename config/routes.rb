Rails.application.routes.draw do

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'work_plans#index'

  health_check_routes

  get '/sets/:set_name', to: 'work_orders#set_search'

  scope '/api/v1' do
    scope 'work_orders/:id' do
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
      jsonapi_resources :work_orders
      jsonapi_resources :work_plans
    end
  end

  namespace :api do
    namespace :v1 do
      jsonapi_resources :jobs, only: [:show, :update] do
        put 'start', to: 'jobs#start'        
        put 'complete', to: 'jobs#complete'
        put 'cancel', to: 'jobs#cancel'
      end
    end
  end



  resources :work_orders

  resources :work_plans do
    resources :build, controller: 'plan_wizard'
    put :dispatch, to: 'work_plans/dispatch#update'
    resources :process_module_choices, only: [:update]
  end

  resources :jobs, only: [] do
    post :revise_output, to: 'jobs/revise_output#create'
    post :forward, to: 'jobs/forward#create', on: :collection
  end

end
