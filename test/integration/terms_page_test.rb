require "test_helper"

class TermsPageTest < ActionDispatch::IntegrationTest
  test "terms explain billing, refunds, AI, and governing law" do
    get terms_path

    assert_response :success
    assert_select "section h2", count: 17
    assert_includes response.body, "Utah"
    assert_includes response.body, "$50"
    assert_includes response.body, Jumpstart.config.support_email
    assert_includes response.body, "307 N 990 E"
    assert_select "a[href='#{refunds_path}']"
    assert_not_includes response.body, "Some suggestions to help create"
    assert_no_match(/\b\d+ students\b/, response.body)
  end
end
