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

  def test_every_job_that_boots_rails_installs_libvips
    workflow = YAML.load_file(File.expand_path("../../.github/workflows/ci.yml", __dir__))

    workflow.fetch("jobs").each do |name, job|
      runs_rails = job.fetch("steps").any? { |step| step["run"]&.include?("bin/rails") }
      next unless runs_rails

      installs_libvips = job.fetch("steps").any? { |step| step["run"]&.include?("libvips") }
      assert installs_libvips, "job '#{name}' boots Rails but does not install libvips"
    end
  end
end
