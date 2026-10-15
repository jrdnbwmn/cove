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
    assert_no_match(/student/i, response.body)
  end

  test "terms explain shared learner capacity and editable learners after downgrading" do
    get terms_path

    assert_response :success
    assert_select "section p", text: "Every plan includes unlimited learners for a single family. When a family reaches 15 active learners, we ask you to contact us so we can raise the limit. Archived learners don't count."
    assert_select "section p", text: "If you move from Premium to Free, nothing is deleted and every learner stays editable."
    assert_no_match(/Free plan's limit|read-only|choose which learners to keep active/i, response.body)
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
