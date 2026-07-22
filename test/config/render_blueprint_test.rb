require "minitest/autorun"
require "yaml"

class RenderBlueprintTest < Minitest::Test
  def test_free_staging_uses_single_mode_puma_without_embedded_solid_queue
    blueprint = YAML.load_file(File.expand_path("../../render.yaml", __dir__))
    service = blueprint.fetch("services").find { |entry| entry["name"] == "cove-staging" }
    environment_variables = service.fetch("envVars").to_h { |entry| [entry.fetch("key"), entry] }

    assert_equal "0", environment_variables.fetch("WEB_CONCURRENCY").fetch("value")
    refute environment_variables.key?("SOLID_QUEUE_IN_PUMA")
  end
end
