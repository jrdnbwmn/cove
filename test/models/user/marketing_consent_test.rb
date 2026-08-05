require "test_helper"

class User::MarketingConsentTest < ActiveSupport::TestCase
  test "derives subscribed users from consent timestamps" do
    assert_predicate users(:marketing_subscribed), :marketing_subscribed?
    assert_not_predicate users(:marketing_unsubscribed), :marketing_subscribed?
    assert_not_predicate users(:one), :marketing_subscribed?
    assert_equal [users(:marketing_subscribed)], User.marketing_subscribed.to_a
  end

  test "validates marketing consent provenance" do
    user = users(:one)

    user.marketing_opt_in_source = "unknown"
    assert_not_predicate user, :valid?
    assert_includes user.errors[:marketing_opt_in_source], "is not included in the list"

    user.marketing_opt_in_source = "registration"
    user.marketing_opt_out_reason = "unknown"
    assert_not_predicate user, :valid?
    assert_includes user.errors[:marketing_opt_out_reason], "is not included in the list"
  end

  test "captures checked creation consent with registration provenance" do
    user = User.new(
      email: "marketing-consent@example.com",
      first_name: "Marketing",
      last_name: "Consent",
      password: UNIQUE_PASSWORD,
      password_confirmation: UNIQUE_PASSWORD,
      terms_of_service: "1",
      marketing_opt_in: "1"
    )

    assert_predicate user, :save
    assert_predicate user, :marketing_subscribed?
    assert_equal "registration", user.marketing_opt_in_source
    assert_not_nil user.marketing_opt_in_at
    assert_nil user.marketing_opt_out_at
    assert_nil user.marketing_opt_out_reason
  end

  test "grants and withdraws marketing consent" do
    user = users(:one)

    assert_predicate user.grant_marketing_consent(source: "settings"), :present?
    user.reload
    assert_predicate user, :marketing_subscribed?
    assert_equal "settings", user.marketing_opt_in_source

    assert_predicate user.withdraw_marketing_consent(reason: "user_app"), :present?
    user.reload
    assert_not_predicate user, :marketing_subscribed?
    assert_equal "user_app", user.marketing_opt_out_reason
    assert_not_nil user.marketing_opt_out_at
  end

  test "repeating the current choice preserves consent provenance and timestamps" do
    user = users(:marketing_subscribed)
    original_opt_in_at = user.marketing_opt_in_at

    assert_predicate user.grant_marketing_consent(source: "settings"), :present?
    user.reload
    assert_equal original_opt_in_at, user.marketing_opt_in_at
    assert_equal "registration", user.marketing_opt_in_source

    user.withdraw_marketing_consent(reason: "user_app")
    user.reload
    original_opt_out_at = user.marketing_opt_out_at

    assert_predicate user.withdraw_marketing_consent(reason: "user_app"), :present?
    user.reload
    assert_equal original_opt_out_at, user.marketing_opt_out_at
    assert_equal "user_app", user.marketing_opt_out_reason
  end

  test "leaves a never-subscribed user unchanged when withdrawing consent" do
    user = users(:one)

    assert_predicate user.withdraw_marketing_consent(reason: "user_app"), :present?
    user.reload
    assert_nil user.marketing_opt_in_at
    assert_nil user.marketing_opt_in_source
    assert_nil user.marketing_opt_out_at
    assert_nil user.marketing_opt_out_reason
  end

  test "allows a user app opt-out to be reversed" do
    user = users(:marketing_unsubscribed)

    assert_predicate user.grant_marketing_consent(source: "settings"), :present?
    user.reload
    assert_predicate user, :marketing_subscribed?
    assert_equal "settings", user.marketing_opt_in_source
    assert_nil user.marketing_opt_out_at
    assert_nil user.marketing_opt_out_reason
  end

  %w[user_loops mailing_list_unsubscribe hard_bounce spam_report].each do |reason|
    test "does not reverse a #{reason} opt-out" do
      user = users(:marketing_unsubscribed)
      user.update!(marketing_opt_out_reason: reason)
      original_attributes = user.slice(*User::MarketingConsent::CONSENT_ATTRIBUTES)

      assert_not user.grant_marketing_consent(source: "settings")
      assert_predicate user, :marketing_opt_out_protected?
      assert_equal original_attributes, user.reload.slice(*User::MarketingConsent::CONSENT_ATTRIBUTES)
    end
  end

  test "clears a hard bounce when the email changes" do
    user = users(:marketing_unsubscribed)
    user.update!(marketing_opt_out_reason: "hard_bounce")

    user.update!(email: "new-address@example.com")

    assert_equal({
      "marketing_opt_in_at" => nil,
      "marketing_opt_in_source" => nil,
      "marketing_opt_out_at" => nil,
      "marketing_opt_out_reason" => nil
    }, user.slice(*User::MarketingConsent::CONSENT_ATTRIBUTES))
  end

  %w[user_loops mailing_list_unsubscribe spam_report].each do |reason|
    test "preserves a #{reason} opt-out when the email changes" do
      user = users(:marketing_unsubscribed)
      user.update!(marketing_opt_out_reason: reason)
      original_attributes = user.slice(*User::MarketingConsent::CONSENT_ATTRIBUTES)

      user.update!(email: "#{reason}@example.com")

      assert_equal original_attributes, user.slice(*User::MarketingConsent::CONSENT_ATTRIBUTES)
    end
  end

  test "record_loops_opt_out escalates severity" do
    user = users(:marketing_subscribed)
    user.record_loops_opt_out(reason: "user_loops", occurred_at: Time.current)
    user.reload

    assert_equal "user_loops", user.marketing_opt_out_reason

    user.record_loops_opt_out(reason: "hard_bounce", occurred_at: Time.current)
    user.reload

    assert_equal "hard_bounce", user.marketing_opt_out_reason
  end

  test "record_loops_opt_out does not de-escalate severity" do
    user = users(:marketing_subscribed)
    user.record_loops_opt_out(reason: "spam_report", occurred_at: Time.current)
    user.reload

    user.record_loops_opt_out(reason: "user_loops", occurred_at: Time.current)
    user.reload

    assert_equal "spam_report", user.marketing_opt_out_reason
  end

  test "record_loops_opt_out no-ops at equal severity" do
    user = users(:marketing_subscribed)
    first_time = 2.days.ago
    user.record_loops_opt_out(reason: "hard_bounce", occurred_at: first_time)
    user.reload

    user.record_loops_opt_out(reason: "hard_bounce", occurred_at: Time.current)
    user.reload

    assert_equal "hard_bounce", user.marketing_opt_out_reason
    assert_in_delta first_time.to_i, user.marketing_opt_out_at.to_i, 1
  end

  test "record_loops_opt_out keeps the earliest occurred_at across escalation" do
    user = users(:marketing_subscribed)
    earliest = 5.days.ago
    user.record_loops_opt_out(reason: "user_loops", occurred_at: earliest)
    user.reload

    user.record_loops_opt_out(reason: "hard_bounce", occurred_at: Time.current)
    user.reload

    assert_equal "hard_bounce", user.marketing_opt_out_reason
    assert_in_delta earliest.to_i, user.marketing_opt_out_at.to_i, 1
  end

  test "record_loops_opt_out records an opt-out for a never-subscribed user" do
    user = users(:one)

    user.record_loops_opt_out(reason: "spam_report", occurred_at: Time.current)
    user.reload

    assert_equal "spam_report", user.marketing_opt_out_reason
    assert_not_nil user.marketing_opt_out_at
  end

  test "grant_marketing_consent(source: loops) clears a Loops-originated opt-out" do
    user = users(:marketing_unsubscribed)
    user.update!(marketing_opt_out_reason: "user_loops")

    assert_predicate user.grant_marketing_consent(source: "loops"), :present?
    user.reload

    assert_predicate user, :marketing_subscribed?
    assert_equal "loops", user.marketing_opt_in_source

    user.record_loops_opt_out(reason: "mailing_list_unsubscribe", occurred_at: Time.current)
    user.reload

    assert_predicate user.grant_marketing_consent(source: "loops"), :present?
    user.reload
    assert_predicate user, :marketing_subscribed?
  end

  %w[hard_bounce spam_report].each do |reason|
    test "grant_marketing_consent(source: loops) is refused for #{reason}" do
      user = users(:marketing_unsubscribed)
      user.update!(marketing_opt_out_reason: reason)

      assert_not user.grant_marketing_consent(source: "loops")
      assert_predicate user, :marketing_opt_out_protected?
    end
  end

  %w[user_loops mailing_list_unsubscribe hard_bounce spam_report].each do |reason|
    test "grant_marketing_consent(source: settings) is still refused for #{reason}" do
      user = users(:marketing_unsubscribed)
      user.update!(marketing_opt_out_reason: reason)

      assert_not user.grant_marketing_consent(source: "settings")
      assert_predicate user, :marketing_opt_out_protected?
    end
  end
end
