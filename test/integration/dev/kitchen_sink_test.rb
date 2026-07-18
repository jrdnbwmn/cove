require "test_helper"

class KitchenSinkTest < ActionDispatch::IntegrationTest
  test "shows the component kitchen sink sections" do
    get "/dev/kitchen_sink"

    assert_response :success
    assert_select "h1", "Component Kitchen Sink"
    assert_select "button.bg-primary.text-primary-foreground", count: 2
    assert_select ".dark", count: 0
    assert_select "[data-controller='ui-modal']", count: 1
    assert_select "[data-controller='ui-dropdown-popover']", count: 1
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

  test "uses the complete Rails Blocks select styling" do
    select_styles = Rails.root.join("app/assets/tailwind/components/tom_select.css").read

    assert_includes select_styles, ".plugin-dropdown_input.focus.dropdown-active .ts-control"
    assert_includes select_styles, "select[data-select-disable-typing-value=\"true\"] + .ts-wrapper .ts-control"
    assert_includes select_styles, ".ts-wrapper.multi.has-items .ts-control"
  end

  test "native form controls suppress the forms plugin focus ring" do
    control_styles = Rails.root.join("app/assets/tailwind/rails_blocks/form_controls.css").read

    assert_includes control_styles, "box-shadow: none;"
  end
end
