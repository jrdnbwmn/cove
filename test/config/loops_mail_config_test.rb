require "minitest/autorun"

class LoopsMailConfigTest < Minitest::Test
  def test_production_selects_loops_without_a_later_provider_override
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    assert_match(/config\.action_mailer\.delivery_method\s*=\s*:loops/, production_config)
    refute_match(/Jumpstart\.config\.email_provider/, production_config)
    refute_match(/config\.action_mailer\.delivery_method\s*=\s*:mailpace/, production_config)
    refute_match(/config\.action_mailer\.delivery_method\s*=\s*:mailgun/, production_config)
    refute_match(/config\.action_mailer\.delivery_method\s*=\s*:postmark/, production_config)
    refute_match(/config\.action_mailer\.delivery_method\s*=\s*:resend/, production_config)
  end

  def test_staging_retains_the_perform_deliveries_kill_switch
    staging_config = File.read(File.expand_path("../../config/environments/staging.rb", __dir__))

    assert_match(/config\.action_mailer\.perform_deliveries\s*=\s*false/, staging_config)
  end

  def test_development_retains_mailbin
    development_config = File.read(File.expand_path("../../config/environments/development.rb", __dir__))

    assert_match(/config\.action_mailer\.delivery_method\s*=\s*:mailbin/, development_config)
  end

  def test_test_retains_test_delivery_method
    test_config = File.read(File.expand_path("../../config/environments/test.rb", __dir__))

    assert_match(/config\.action_mailer\.delivery_method\s*=\s*:test/, test_config)
  end
end
