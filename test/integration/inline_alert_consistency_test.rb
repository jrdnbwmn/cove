require "test_helper"

class FlashVariantPreviewController < ApplicationController
  def show
    flash.now[params[:flash_key].to_sym] = params[:flash_message]
    render template: "public/index"
  end
end

class InlineAlertConsistencyTest < ActionDispatch::IntegrationTest
  test "each flash key renders the expected AlertComponent variant" do
    with_routing do |routes|
      routes.draw do
        get "/flash-variant-preview", to: "flash_variant_preview#show"
      end

      {
        notice: "border-blue-200",
        success: "border-green-200",
        alert: "border-red-200",
        error: "border-red-200"
      }.each do |flash_key, border_class|
        get "/flash-variant-preview", params: {flash_key: flash_key, flash_message: "Test #{flash_key} message"}

        assert_response :success
        assert_select "#flash .#{border_class}", text: "Test #{flash_key} message"
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
