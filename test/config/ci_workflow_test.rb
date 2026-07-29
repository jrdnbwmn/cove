require "minitest/autorun"
require "yaml"

class CiWorkflowTest < Minitest::Test
  FAILURE_MESSAGE = "RAILS_MASTER_KEY (the repo secret) only decrypts " \
    "config/credentials/test.yml.enc. Any job that boots Rails outside " \
    "RAILS_ENV=test will fail at boot trying to decrypt the wrong " \
    "credentials file with it."

  def test_every_job_boots_rails_as_the_test_environment
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/ci.yml", __dir__))

    assert_equal "test", workflow.fetch("env").fetch("RAILS_ENV"), FAILURE_MESSAGE

    workflow.fetch("jobs").each do |name, job|
      job_env = job.fetch("env", {})
      next unless job_env.key?("RAILS_ENV")

      assert_equal "test", job_env.fetch("RAILS_ENV"), "job '#{name}': #{FAILURE_MESSAGE}"
    end
  end

  def test_rails_boot_jobs_install_libvips
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/ci.yml", __dir__))

    %w[test system seeds].each do |name|
      commands = workflow.fetch("jobs").fetch(name).fetch("steps").filter_map { |step| step["run"] }

      assert_includes commands, "sudo apt-get update && sudo apt-get install -y --no-install-recommends libvips",
        "job '#{name}' must install libvips before booting Rails"
    end
  end
end
