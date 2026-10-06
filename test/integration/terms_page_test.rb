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
    assert_no_match(/\b\d+ learners\b/, response.body)
    assert_no_match(/student/i, response.body)
  end

  test "terms and privacy pages show the October 6, 2026 last updated date" do
    [terms_path, privacy_path].each do |path|
      get path

      assert_response :success
      assert_includes response.body, "October 06, 2026"
    end
  end

  test "terms and privacy pages say learner, not student" do
    get terms_path
    assert_includes response.body, "any learner you add to Cove"
    assert_includes response.body, "Learner information"
    assert_includes response.body, "Learner limits"

    get privacy_path
    assert_includes response.body, "Learner information:"
    assert_includes response.body, "your learners"
  end
end
