resources :accounts, only: [:show, :edit, :update, :destroy] do
  resource :transfer, module: :accounts
  resources :account_users, path: :members, only: :destroy
  resources :account_invitations, path: :invitations, module: :accounts do
    member do
      post :resend
    end
  end
end
resources :account_invitations
