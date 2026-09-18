require "test_helper"

class PremiumAccessPreviewController < ApplicationController
  before_action :require_premium!, only: :show

  def show
    render plain: "Premium content"
  end

  def status
    render plain: premium?.to_s
  end

  def pricing
    render plain: "Pricing"
  end
end

class PremiumAccessTest < ActionDispatch::IntegrationTest
  test "a free user is redirected to pricing with a premium notice" do
    sign_in users(:noaccount)

    with_premium_access_routes do
      get "/premium-only"

      assert_redirected_to pricing_path
      assert_equal "That's a Premium feature. Upgrade to unlock it.", flash[:notice]
    end
  end

  test "a premium user can access a premium-only page" do
    sign_in users(:subscribed)

    with_premium_access_routes do
      get "/premium-only"

      assert_response :success
      assert_equal "Premium content", response.body
    end
  end

  test "the premium helper reports false when signed out" do
    with_premium_access_routes do
      get "/premium-status"

      assert_response :success
      assert_equal "false", response.body
    end
  end

  private

  def with_premium_access_routes(&)
    with_routing do |routes|
      routes.draw do
        get "/premium-only", to: "premium_access_preview#show"
        get "/premium-status", to: "premium_access_preview#status"
        get "/pricing", to: "premium_access_preview#pricing", as: :pricing
      end

      yield
    end
  end
end
