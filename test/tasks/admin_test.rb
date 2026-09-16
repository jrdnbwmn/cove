require "test_helper"
require "rake"

class AdminTaskTest < ActiveSupport::TestCase
  TASK_FILE = Rails.root.join("lib/tasks/admin.rake")
  BOOTSTRAP_ENVIRONMENT_KEYS = %w[BOOTSTRAP_ADMIN_EMAIL BOOTSTRAP_ADMIN_NAME].freeze

  setup do
    @original_rake_application = Rake.application
    reload_tasks
  end

  teardown do
    Rake.application = @original_rake_application
  end

  test "bootstrap forwards the configured email and name to the service" do
    with_bootstrap_environment(email: "admin@example.com", name: "Cove Administrator") do
      received_arguments = nil
      no_op_service = Object.new.tap { |service| service.define_singleton_method(:call) {} }

      AdminBootstrap.stub(:new, ->(email:, name:) {
        received_arguments = {email:, name:}
        no_op_service
      }) do
        invoke("admin:bootstrap")
      end

      assert_equal({email: "admin@example.com", name: "Cove Administrator"}, received_arguments)
    end
  end

  test "bootstrap skips without creating a user when no email is configured" do
    with_bootstrap_environment(email: nil, name: nil) do
      output = nil

      assert_no_difference -> { User.count } do
        output = invoke("admin:bootstrap")
      end

      assert_includes output, "[admin:bootstrap] skipped: BOOTSTRAP_ADMIN_EMAIL unset"
    end
  end

  private

  def invoke(name)
    task = Rake::Task[name]
    task.reenable
    output, = capture_io { task.invoke }
    output
  end

  def reload_tasks
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load TASK_FILE
  end

  def with_bootstrap_environment(email:, name:)
    original_values = BOOTSTRAP_ENVIRONMENT_KEYS.to_h { |key| [key, ENV[key]] }
    ENV.delete("BOOTSTRAP_ADMIN_EMAIL") if email.nil?
    ENV.delete("BOOTSTRAP_ADMIN_NAME") if name.nil?
    ENV["BOOTSTRAP_ADMIN_EMAIL"] = email if email
    ENV["BOOTSTRAP_ADMIN_NAME"] = name if name

    yield
  ensure
    original_values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
