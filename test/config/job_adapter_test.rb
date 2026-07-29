require "minitest/autorun"

class JobAdapterTest < Minitest::Test
  def test_staging_uses_async_active_job_adapter_without_solid_queue_config
    staging_config = File.read(File.expand_path("../../config/environments/staging.rb", __dir__))

    assert_match(/config\.active_job\.queue_adapter\s*=\s*:async/, staging_config)
    refute_match(/:inline/, staging_config)
    refute_match(/Jumpstart\.config\.queue_adapter/, staging_config)
    refute_match(/SOLID_QUEUE_IN_PUMA/, staging_config)
  end

  def test_staging_does_not_attempt_unconfigured_outbound_email_delivery
    staging_config = File.read(File.expand_path("../../config/environments/staging.rb", __dir__))

    assert_match(/config\.action_mailer\.perform_deliveries\s*=\s*false/, staging_config)
  end

  def test_production_uses_solid_queue_when_jumpstart_has_no_adapter
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    assert_match(/queue_adapter\s*=\s*Jumpstart\.config\.queue_adapter\s*\|\|\s*:solid_queue/, production_config)
  end
end
