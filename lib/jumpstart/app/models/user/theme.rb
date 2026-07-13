module User::Theme
  extend ActiveSupport::Concern

  included do
    store_accessor :preferences, :theme
  end

  def system_theme? = theme.blank?

  def dark_theme? = theme == "dark"

  def light_theme? = theme == "light"
end
