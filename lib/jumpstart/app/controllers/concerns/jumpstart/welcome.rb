module Jumpstart::Welcome
  extend ActiveSupport::Concern

  included do
    prepend_before_action :jumpstart_welcome
    prepend_before_action :upgrade_yaml_config
  end

  def jumpstart_welcome
    redirect_to jumpstart.root_path(welcome: true) unless Jumpstart::Configuration.config_exists?
  end

  private

  def upgrade_yaml_config
    if (path = Rails.root.join("config/jumpstart.yml")) && path.exist?
      Jumpstart::Configuration.new(YAML.load_file(path)).write_config
      File.delete(path)
      Jumpstart.restart
      redirect_to root_path(reload: true), notice: "Your app is upgrading to the new configuration..."
    end
  end
end
