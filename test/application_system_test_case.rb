require "test_helper"

Dir["#{File.dirname(__FILE__)}/support/system/**/*.rb"].sort.each { |f| require f }

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Backport
  def self.served_by(host:, port:)
    Capybara.server_host = host
    Capybara.server_port = port
  end

  if ENV["CAPYBARA_SERVER_PORT"]
    served_by host: "rails-app", port: ENV["CAPYBARA_SERVER_PORT"]

    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400], options: {
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    }
  else
    driven_by :selenium, using: ENV.fetch("DRIVER", :headless_chrome).to_sym, screen_size: [1400, 1400]
  end

  include Warden::Test::Helpers
  include TrixSystemTestHelper
  include TurboResilienceSystemHelper

  def wait_for_turbo_navigation
    # AIDEV-NOTE: Modal redirects close the dialog before Turbo replaces the body.
    # Poll JS state so the wait never holds a WebElement from the old page.
    # A full reload clears the marker; a Turbo visit sets it on turbo:load.
    page.execute_script(<<~JAVASCRIPT)
      window.systemTestNavigationComplete = false
      document.addEventListener("turbo:load", () => {
        window.systemTestNavigationComplete = true
      }, {once: true})
    JAVASCRIPT

    yield

    page.document.synchronize do
      complete = page.evaluate_script(<<~JAVASCRIPT)
        window.systemTestNavigationComplete === true ||
          (window.systemTestNavigationComplete === undefined && document.readyState === "complete")
      JAVASCRIPT
      raise Capybara::ExpectationNotMet, "Turbo navigation did not finish" unless complete
    end
  end
end

Capybara.default_max_wait_time = 10

# Add a route for easily switching accounts in system tests
Rails.application.routes.append do
end
Rails.application.reload_routes!
