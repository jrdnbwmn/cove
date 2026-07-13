class Jumpstart::OverrideGenerator < Rails::Generators::Base
  source_root Jumpstart::Engine.root

  argument :paths, type: :array, banner: "path path"

  def self.usage_path = File.expand_path("USAGE", __dir__)

  def copy_paths
    paths.each do |path|
      Dir.exist?(find_in_source_paths(path)) ? directory(path) : copy_file(path)
    end
  end
end
