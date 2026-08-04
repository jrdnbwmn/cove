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

  def test_staging_declares_a_private_recipient_allowlist
    blueprint = YAML.load_file(File.expand_path("../../render.yaml", __dir__))
    service = blueprint.fetch("services").find { |entry| entry["name"] == "cove-staging" }
    allowlist = service.fetch("envVars").find { |entry| entry["key"] == "STAGING_EMAIL_RECIPIENT_ALLOWLIST" }

    assert_equal false, allowlist.fetch("sync")
    refute allowlist.key?("value")
  end

  def test_dormant_production_blueprint_is_valid_and_ready_for_cutover
    service = dormant_production_service
    environment_variables = service.fetch("envVars").to_h { |entry| [entry.fetch("key"), entry] }

    assert_equal "starter", service.fetch("plan")
    assert_equal "0", environment_variables.fetch("WEB_CONCURRENCY").fetch("value")
    assert_equal "true", environment_variables.fetch("SOLID_QUEUE_IN_PUMA").fetch("value")
    assert_equal "cove-production-db", environment_variables.fetch("DATABASE_URL").dig("fromDatabase", "name")
    refute environment_variables.key?("CACHE_DATABASE_URL")
    refute environment_variables.key?("QUEUE_DATABASE_URL")
    refute environment_variables.key?("CABLE_DATABASE_URL")
    assert_equal "bundle exec rails db:prepare", service.fetch("preDeployCommand")
    refute_includes service.fetch("startCommand"), "db:prepare"
    assert_equal false, service.fetch("autoDeploy")
  end

  def test_production_resources_remain_dormant_in_live_blueprint
    blueprint = YAML.load_file(File.expand_path("../../render.yaml", __dir__))

    refute blueprint.fetch("services").any? { |service| service["name"] == "cove-production" }
    refute blueprint.fetch("databases", []).any? { |database| database["name"] == "cove-production-db" }
  end

  private

  def dormant_production_service
    lines = File.readlines(File.expand_path("../../render.yaml", __dir__), chomp: true)
    start_index = lines.index("  # >>> production (dormant)")
    end_index = lines.index("  # <<<")
    production_yaml = lines[(start_index + 1)...end_index].map do |line|
      line.sub(/^(\s*)#\s?/) { Regexp.last_match(1) }
    end.join("\n")

    YAML.load(production_yaml).fetch("services").fetch(0)
  end
end
