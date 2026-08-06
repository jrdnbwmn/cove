# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  draw :jumpstart

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

  # Public marketing homepage
  root to: "public#index"

  constraints ->(_request) { Rails.env.staging? } do
    namespace :staging do
      scope :verification, controller: :verification do
        post :status
        post :audit
        post :create_plan
        post :invite
        post :subscription_renewing
        post :subscription_trial_will_end
        post :subscription_trial_ended
        post :cancellation_reason
        post :enqueue_failure
        post :cleanup
        post :clear_stray_subscription
        post :cancel_verification_subscription
        post :link_test_clock_customer
        post :reset_stripe_customer
      end
    end
  end

  if Rails.env.local?
    mount Lookbook::Engine, at: "/lookbook" if defined?(Lookbook::Engine)
    get "dev/kitchen_sink", to: "dev/kitchen_sink#show"
  end
end
