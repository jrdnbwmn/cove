require "jumpstart/engine"

module Jumpstart
  autoload :AccountMiddleware, "jumpstart/account_middleware"
  autoload :Configuration, "jumpstart/configuration"
  autoload :Mentions, "jumpstart/mentions"
  autoload :Multitenancy, "jumpstart/multitenancy"
  autoload :Omniauth, "jumpstart/omniauth"
  autoload :SubscriptionExtensions, "jumpstart/subscription_extensions"

  def self.restart = run_command "rails restart"

  # https://stackoverflow.com/a/25615344/277994
  def self.bundle = run_command "bundle install"

  def self.run_command(command)
    Bundler.with_original_env { system command }
  end

  def self.find_plan(id)
    return if id.nil?
    config.plans.find { |plan| plan["id"].to_s == id.to_s }
  end

  def self.processor_plan_id_for(id, interval, processor)
    find_plan(id)[interval]["#{processor}_id"]
  end

  # Commands to be run after bundle install
  def self.post_install
    if config.gems.include?("refer") && !Dir[Rails.root.join("db/migrate/**/*refer*.refer.rb")].any?
      run_command("rails refer:install:migrations")
    end
  end

  def self.grant_system_admin!(user)
    User.connection.execute("UPDATE users SET admin=true WHERE users.id='#{user.id}'")
    user.reload
  end

  def self.revoke_system_admin!(user)
    User.connection.execute("UPDATE users SET admin=false WHERE users.id='#{user.id}'")
    user.reload
  end

  def self.copy_default_overrides
    [
      "app/views/layouts/application.html.erb",
      "app/views/application/_head.html.erb",
      "app/views/application/_left_nav.html.erb",
      "app/views/application/_right_nav.html.erb",
      "app/views/dashboard/show.html.erb",
      "app/views/public/about.html.erb",
      "app/views/users/agreements/_privacy_policy.html.erb",
      "app/views/users/agreements/_terms_of_service.html.erb"
    ].each do |path|
      unless Rails.root.join(path).exist?
        FileUtils.makedirs Rails.root.join(File.dirname(path))
        FileUtils.copy Engine.root.join(path), Rails.root.join(path)
      end
    end
  end
end
