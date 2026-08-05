module LoopsContactGate
  def initialize(config: Rails.application.config_for(:loops), environment: Rails.env, client: nil, client_factory: -> { LoopsClient.client })
    @config = config
    @environment = environment
    @client = client
    @client_factory = client_factory
  end

  private

  attr_reader :config, :environment, :client_factory

  def client
    @client ||= client_factory.call
  end

  def production?
    environment.production?
  end

  def contact_sync_enabled?
    config.contact_sync_enabled == true
  end

  def current_app_opt_in?(user)
    return false unless user.marketing_subscribed?
    return false if user.marketing_opt_in_source == "loops"

    true
  end
end
