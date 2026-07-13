module Jumpstart
  class Engine < ::Rails::Engine
    isolate_namespace Jumpstart
    engine_name "jumpstart"

    config.app_generators do |g|
      g.templates.unshift File.expand_path("../templates", __dir__)
      g.scaffold_stylesheet false
    end

    config.to_prepare do
      ::ApplicationController.helper(Jumpstart::Engine.helpers)
      ::Api::BaseController.helper(Jumpstart::Engine.helpers)
      ::ApplicationController.include(Jumpstart::Welcome) if Rails.env.development?
    end

    initializer "turbo.native.navigation.helper" do
      ActiveSupport.on_load(:action_controller_base) do
        include Turbo::Native::Navigation
      end
    end

    initializer "jumpstart.account_middleware" do |app|
      if Jumpstart::Multitenancy.path? || Rails.env.test?
        app.config.middleware.use Jumpstart::AccountMiddleware
      end
    end

    if Rails.env.development?
      initializer "jumpstart.copy_default_overrides" do
        Jumpstart.copy_default_overrides
      end
    end
  end
end
