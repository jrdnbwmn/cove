require "test_helper"

class FlashVariantPreviewController < ApplicationController
  def show
    flash.now[params[:flash_key].to_sym] = params[:flash_message]
    render template: "public/about"
  end
end

class InlineAlertConsistencyTest < ActionDispatch::IntegrationTest
  test "ordinary pages bridge each flash key to the toast host" do
    with_routing do |routes|
      routes.draw do
        get "/flash-variant-preview", to: "flash_variant_preview#show"
      end

      %i[notice success alert error].each do |flash_key|
        get "/flash-variant-preview", params: {flash_key: flash_key, flash_message: "Test #{flash_key} message"}

        assert_response :success
        assert_select "[data-controller='flash-toast'][data-flash-toast-message-value='Test #{flash_key} message']"
      end
    end
  end

  test "form error summary renders as an error AlertComponent" do
    post user_registration_url, params: {
      user: {
        name: "Test User",
        email: "",
        password: "TestPassword",
        terms_of_service: "1"
      }
    }

    assert_response :unprocessable_entity
    assert_select "[class*='border-red-200']" do
      assert_select "*", text: /prohibited this user from being saved:/
    end
  end
end
