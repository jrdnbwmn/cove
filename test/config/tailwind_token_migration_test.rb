require "minitest/autorun"

class TailwindTokenMigrationTest < Minitest::Test
  LEGACY_PRIMARY_TOKENS = [
    "var(--bg-primary)",
    "var(--bg-primary-hover)",
    "var(--text-on-primary)",
    "var(--border-primary)",
    "var(--border-primary-hover)",
    "var(--text-primary)",
    "var(--text-primary-hover)"
  ].freeze

  def test_component_stylesheets_never_reference_legacy_primary_tokens
    stylesheet_paths.each do |path|
      stylesheet = File.read(path)

      LEGACY_PRIMARY_TOKENS.each do |token|
        refute stylesheet.include?(token), "#{path} references #{token}"
      end
    end
  end

  def test_legacy_primary_tokens_are_no_longer_defined
    light_theme = File.read(project_root.join("app/assets/tailwind/themes/light.css"))

    refute(/^\s*--(bg|text-on|text|border)-primary(-hover)?:/.match?(light_theme))
  end

  private

  def stylesheet_paths
    Dir.glob([project_root.join("app/**/*.css"), project_root.join("lib/**/*.css")]).reject do |path|
      path.start_with?(project_root.join("app/assets/builds/").to_s)
    end
  end

  def project_root
    Pathname.new(File.expand_path("../..", __dir__))
  end
end
