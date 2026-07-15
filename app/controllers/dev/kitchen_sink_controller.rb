module Dev
  class KitchenSinkController < ApplicationController
    # AIDEV-NOTE: This guard keeps the development-only UI reference unavailable outside local environments.
    before_action :ensure_local_environment

    def show
    end

    private

    def ensure_local_environment
      head :not_found unless Rails.env.local?
    end
  end
end
