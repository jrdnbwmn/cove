class ApiClientGenerator < Rails::Generators::NamedBase
  Endpoint = Data.define(:name, :verb) do
    def self.parse(attribute)
      return attribute if attribute.is_a? Endpoint
      name, verb, _ = attribute.split(":")
      new(name, verb || "get")
    end

    def index? = name.start_with? "list"

    def show? = verb == "get"

    def create? = verb == "post"

    def update? = ["patch", "put"].include? verb

    def destroy? = verb == "delete"
  end

  source_root File.expand_path("templates", __dir__)

  argument :attributes, type: :array, default: [], banner: "method[:type] method[:type]"

  class_option :url, type: :string, default: "https://api.example.com", desc: "API Base URL"

  def copy_templates
    template "client.rb", "app/clients/#{file_path}_client.rb"
    template "client_test.rb", "test/clients/#{file_path}_client_test.rb"
  end

  # Note: This overrides the built-in parse_attributes! method from Rails::Generators::NamedBase
  # Instead of retruning instances of GeneratedAttributes (which makes sense for models)
  # we want to return instances of ApiMethod.
  def parse_attributes!
    self.attributes = Array.wrap(attributes).map do |attr|
      Endpoint.parse(attr)
    end
  end

  def url = options[:url]
end
