require "minitest/autorun"
require "yaml"

class HoneybadgerConfigTest < Minitest::Test
  def test_error_reports_never_include_session_data
    config = YAML.load_file(File.expand_path("../../config/honeybadger.yml", __dir__))

    assert_equal true, config.fetch("request").fetch("disable_session")
  end

  def test_api_key_is_read_from_credentials_and_never_committed
    config = YAML.load_file(File.expand_path("../../config/honeybadger.yml", __dir__))

    assert_match(/\A<%=\s*Rails\.application\.credentials\.dig\(:honeybadger, :api_key\)\s*%>\z/, config.fetch("api_key"))
  end

  def test_honeybadger_integration_is_enabled
    jumpstart_config = File.read(File.expand_path("../../config/jumpstart.rb", __dir__))

    assert_match(/"integrations"\s*=>\s*\[[^\]]*"honeybadger"/, jumpstart_config)
  end
end
