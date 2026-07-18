require "test_helper"

class MinimalLayoutPreviewController < ApplicationController
  layout "minimal"

  def show
    render template: "public/index"
  end
end

class LayoutsTest < ActionDispatch::IntegrationTest
  test "minimal layout stays light for users with a saved dark preference" do
    user = users(:one)
    user.update!(preferences: {theme: "dark"})
    sign_in user

    with_routing do |routes|
      routes.draw do
        root to: "minimal_layout_preview#show"
        get "/minimal-layout", to: "minimal_layout_preview#show"
      end

      get "/minimal-layout"

      assert_response :success
      assert_not_includes response.body, '<html class="dark"'
      assert_not_includes response.body, 'data-controller="theme"'
      assert_not_includes response.body, "data-theme-preference-value"
    end
  end
end
