require "test_helper"

class JavascriptPayloadTest < ActionDispatch::IntegrationTest
  test "pages do not ship the unused animation library" do
    get root_path

    assert_response :success
    assert_not_includes response.body, "motion-dom"
    assert_not_includes response.body, "framer-motion"
  end

  test "pages do not preload the select library" do
    get root_path

    assert_response :success
    assert_select "link[rel='modulepreload'][href*='tom-select']", count: 0
  end

  test "marketing pages do not load Stripe" do
    get root_path
    assert_not_includes response.body, "js.stripe.com"

    get pricing_path
    assert_not_includes response.body, "js.stripe.com"
  end

  test "regular pages do not preload the rich-text editor" do
    get root_path

    assert_select "link[rel='modulepreload'][href*='lexxy']", count: 0
    assert_select "link[rel='modulepreload'][href*='actiontext']", count: 0
  end

  test "regular pages do not load rich-text styles" do
    get root_path

    assert_select "link[href*='lexxy'][rel='stylesheet']", count: 0
  end

  test "announcement pages load rich-text styles and script" do
    get announcement_path(announcements(:one))

    assert_select "link[href*='lexxy'][rel='stylesheet']"
    assert_select "script[type='module']", text: /import "rich_text"/
  end
end
