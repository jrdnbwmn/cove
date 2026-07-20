require "test_helper"
require "nokogiri"

class StaticErrorPagesTest < ActiveSupport::TestCase
  PAGES = {
    "400.html" => {
      status: "400",
      heading: "Bad request",
      description: "We couldn't process this request. Please check the address and try again.",
      icon: "circle",
      home_action: true
    },
    "422.html" => {
      status: "422",
      heading: "Your request couldn't be completed.",
      description: "This page may have expired. Return home and try again.",
      icon: "clock",
      home_action: true
    },
    "404.html" => {
      status: "404",
      heading: "Page not found",
      description: "Sorry, the page you're looking for doesn't exist or may have moved.",
      icon: "compass",
      home_action: true
    },
    "500.html" => {
      status: "500",
      heading: "Something went wrong",
      description: "Sorry, we had a problem loading this page. Please try again.",
      icon: "server",
      home_action: true
    },
    "406-unsupported-browser.html" => {
      status: "406",
      heading: "Your browser isn't supported",
      description: "Please update your browser to the latest version to continue.",
      icon: "rect",
      home_action: false
    }
  }.freeze

  PAGES.each do |filename, page|
    test "#{page[:status]} static page is self-contained and accessible" do
      document = static_page(filename)

      assert_equal "en", document.at_css("html")["lang"]
      assert_equal "noindex, nofollow", document.at_css('meta[name="robots"]')["content"]
      assert_includes document.at_css("title").text, page[:status]
      assert_equal page[:heading], document.at_css("h1").text.strip
      assert_includes document.text, page[:description]
      assert_equal 1, document.css("h1").count
      assert document.at_css("header")
      assert document.at_css("main")

      wordmark = document.at_css('header a[href="/"]')
      assert_equal "Cove", wordmark.text.strip

      icon = document.at_css("svg[aria-hidden='true'][focusable='false']")
      assert icon
      assert icon.at_css(page[:icon])

      home_action = document.at_css('main a[href="/"]')
      if page[:home_action]
        assert_equal "Back to home", home_action.text.strip
      else
        assert_nil home_action
      end
    end

    test "#{page[:status]} static page has no external dependencies or modern CSS" do
      html = static_page_html(filename)
      document = Nokogiri::HTML5(html)
      css = document.css("style").map(&:text).join

      assert document.at_css("style")
      assert_empty document.css("script")
      assert_empty document.css('link[rel="stylesheet"], link[href], img, source')
      assert_empty document.css("svg use")
      assert_empty document.css("a").reject { |link| link["href"] == "/" }
      assert_no_match(/@import|url\s*\(/i, html)
      assert_no_match(/clamp\(|var\(|oklch\(/i, css)
      assert_no_match(/\{\s*@(?:media|supports|container)/i, css)
    end
  end

  private

  def static_page(filename)
    Nokogiri::HTML5(static_page_html(filename))
  end

  def static_page_html(filename)
    Rails.root.join("public", filename).read
  end
end
