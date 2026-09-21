# AIDEV-NOTE: This replaces (not extends) the engine controller in lib/jumpstart, so all
# five actions must stay in sync with it. Only `index` differs: it loads plans for the homepage.
class PublicController < ApplicationController
  def index
    @monthly_plans, @yearly_plans = Plan.visible.sorted.partition(&:monthly?)
  end

  def about
  end

  def terms
    @agreement = Rails.application.config.agreements.find { it.id == :terms_of_service }
  end

  def privacy
    @agreement = Rails.application.config.agreements.find { it.id == :privacy_policy }
  end

  def reset_app
    # Hotwire Native needs an empty page to route authentication and reset the app.
    # We can't head: 200 because we also need the Turbo JavaScript in <head>.
    render html: "Redirecting..."
  end
end
