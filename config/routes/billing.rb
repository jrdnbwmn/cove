resource :pricing, controller: :pricing

namespace :checkout do
  resource :return, only: [:show]
end
resource :checkout

resource :billing, controller: :billing
namespace :billing do
  resource :info

  namespace :subscriptions do
    resource :paddle_billing, controller: :paddle_billing, only: [:show, :edit]
    resource :paddle_classic, controller: :paddle_classic, only: [:show]
  end

  resources :subscriptions, only: [:index, :edit, :update] do
    scope module: :subscriptions do
      resource :payment_method
      resource :cancel
      resource :pause
      resource :resume
      resource :upcoming
    end
  end

  resources :charges do
    member do
      get :invoice
    end
  end
end
