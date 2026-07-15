require "test_helper"

class KitchenSinkTest < ActionDispatch::IntegrationTest
  test "shows the component kitchen sink sections" do
    get "/dev/kitchen_sink"

    assert_response :success
    assert_select "h1", "Component Kitchen Sink"
    %w[Buttons Forms Feedback Overlays Navigation Data\ Display].each do |section|
      assert_select "h2", section
    end
  end

  test "is unavailable outside local environments" do
    Rails.env.stub(:local?, false) do
      get "/dev/kitchen_sink"
    end

    assert_response :not_found
  end
end
