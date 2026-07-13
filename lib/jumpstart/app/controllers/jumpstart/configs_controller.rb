module Jumpstart
  class ConfigsController < ApplicationController
    def show
      @user = User.new
      @config = Jumpstart::Configuration.load!
      @omniauth_providers = Jumpstart::Omniauth.all_providers
    end

    def create
      Jumpstart::Configuration.new(config_params).save

      # Install the new gem dependencies
      Jumpstart.bundle
      Jumpstart.post_install
      Jumpstart.restart

      redirect_to root_path(reload: true), notice: "Your app is restarting with the new configuration..."
    end

    private

    def config_params
      params.require(:configuration)
        .permit(
          :application_name,
          :business_name,
          :business_address,
          :domain,
          :default_from_email,
          :support_email,
          :background_job_processor,
          :email_provider,
          :account_types,
          :apns,
          :fcm,
          integrations: [],
          omniauth_providers: [],
          payment_processors: [],
          multitenancy: [],
          gems: []
        )
    end
  end
end
