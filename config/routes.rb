# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  draw :jumpstart
  draw :webhooks

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  authenticated :user do
    root to: "dashboard#show", as: :user_root
    # Alternate route to use if logged in users should still see public root
    # get "/dashboard", to: "dashboard#show", as: :user_root
  end

  resources :schedules, only: :index
  resources :subjects, only: :index
  # AIDEV-NOTE: Must stay above `resources :learners`, or /learners/kept/edit matches learners#edit with id "kept".
  scope :learners, as: :learners, module: :learners do
    resource :kept, only: %i[edit update], controller: :kept
  end
  resources :learners do
    get :delete, on: :member
    resource :archive, only: %i[create destroy], module: :learners
  end
  resource :support, only: :show, controller: :support

  # Public marketing homepage
  root to: "public#index"

  if Rails.env.local?
    mount Lookbook::Engine, at: "/lookbook" if defined?(Lookbook::Engine)
    get "dev/kitchen_sink", to: "dev/kitchen_sink#show"
    get "dev/typography", to: "dev/typography#show"
  end
end
