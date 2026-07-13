if Rails.env.local?
  mount Jumpstart::Engine, at: "/jumpstart"
  mount Mailbin::Engine, at: "/mailbin"
end

authenticated :user, lambda { |u| u.admin? } do
  draw :madmin
end

draw :accounts
draw :api
draw :billing
draw :hotwire_native
draw :users

resources :announcements, only: [:index, :show]

namespace :action_text do
  resources :embeds, only: [:create], constraints: {id: /[^\/]+/}
end

scope controller: :public do
  get :about
  get :terms
  get :privacy
  get :reset_app
end

match "/404", via: :all, to: "errors#not_found"
match "/500", via: :all, to: "errors#internal_server_error"
