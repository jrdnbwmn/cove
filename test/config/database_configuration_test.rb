require "minitest/autorun"
require "erb"
require "yaml"
require "uri"

class DatabaseConfigurationTest < Minitest::Test
  def test_production_roles_use_distinct_database_urls_without_primary_credentials
    configuration = rendered_configuration("postgres://u:p@host:5432/cove_production")
    production_roles = configuration.fetch("production").slice("cache", "queue", "cable")

    role_urls = production_roles.transform_values { |role| role.fetch("url") }

    assert_equal ["/jumpstart_production_cache", "/jumpstart_production_queue", "/jumpstart_production_cable"], role_urls.values.map { |url| URI.parse(url).path }
    assert_equal 4, (role_urls.values + ["postgres://u:p@host:5432/cove_production"]).uniq.size
    production_roles.each_value do |role|
      refute role.key?("username")
      refute role.key?("password")
    end
  end

  def test_staging_roles_keep_using_distinct_database_urls
    configuration = rendered_configuration("postgres://u:p@host:5432/cove_staging")
    staging_roles = configuration.fetch("staging").slice("cache", "queue", "cable")

    assert_equal ["/jumpstart_staging_cache", "/jumpstart_staging_queue", "/jumpstart_staging_cable"], staging_roles.values.map { |role| URI.parse(role.fetch("url")).path }
  end

  def test_configuration_renders_without_database_url
    configuration = rendered_configuration(nil)

    %w[staging production].each do |environment|
      %w[cache queue cable].each do |role|
        assert_nil configuration.fetch(environment).fetch(role)["url"]
      end
    end
  end

  private

  def rendered_configuration(database_url)
    previous_database_url = ENV["DATABASE_URL"]
    database_url ? ENV["DATABASE_URL"] = database_url : ENV.delete("DATABASE_URL")

    rendered = ERB.new(File.read(File.expand_path("../../config/database.yml", __dir__))).result
    YAML.load(rendered, aliases: true)
  ensure
    previous_database_url ? ENV["DATABASE_URL"] = previous_database_url : ENV.delete("DATABASE_URL")
  end
end
