require "minitest/autorun"
require "yaml"

class CiWorkflowTest < Minitest::Test
  def test_every_job_boots_rails_as_the_test_environment
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/ci.yml", __dir__))

    assert_equal "test", workflow.fetch("env").fetch("RAILS_ENV"),
      "RAILS_MASTER_KEY (the repo secret) only decrypts config/credentials/test.yml.enc. " \
      "Any job that boots Rails outside RAILS_ENV=test will fail at boot trying to decrypt " \
      "the wrong credentials file with it."
  end
end
