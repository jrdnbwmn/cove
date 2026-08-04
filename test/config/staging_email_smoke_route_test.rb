require "minitest/autorun"

class StagingEmailSmokeRouteTest < Minitest::Test
  def test_temporary_smoke_route_is_staging_only_and_uses_a_fixed_blocked_recipient
    routes = File.read(File.expand_path("../../config/routes.rb", __dir__))

    assert_match(/if Rails\.env\.staging\?/, routes)
    assert_match(/TEMPORARY.*cov-46-blocked@example\.invalid/m, routes)
    assert_match(/User\.new\(email: "cov-46-blocked@example\.invalid"\)/, routes)
    assert_match(/LoopsDeviseMailer\.password_change/, routes)
  end
end
