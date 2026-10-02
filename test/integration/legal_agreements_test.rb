require "test_helper"

class LegalAgreementsTest < ActionDispatch::IntegrationTest
  test "signed-in parent is not sent to the agreement screen" do
    user = users(:one)
    user.update!(accepted_terms_at: 1.year.ago, accepted_privacy_at: 1.year.ago)
    sign_in user

    get user_root_path

    assert_no_match %r{/agreements/}, response.location.to_s
  end

  test "terms and privacy agreements are configured without prompting" do
    agreements = Rails.application.config.agreements

    assert_equal [:terms_of_service, :privacy_policy], agreements.map(&:id)
    assert_not agreements.any?(&:prompt_when_updated)
  end
end
