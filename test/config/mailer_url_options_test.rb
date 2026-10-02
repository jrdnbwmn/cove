require "minitest/autorun"

class MailerUrlOptionsTest < Minitest::Test
  def test_production_and_staging_emails_link_over_https
    ["production", "staging"].each do |environment|
      config = File.read(File.expand_path("../../config/environments/#{environment}.rb", __dir__))

      assert_match(/config\.action_mailer\.default_url_options\s*=\s*\{[^}]*protocol:\s*"https"[^}]*\}/, config)
    end
  end
end
