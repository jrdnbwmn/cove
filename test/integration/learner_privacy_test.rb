require "test_helper"

class LearnerPrivacyTest < ActiveSupport::TestCase
  test "learner name and grade level are filtered from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(learner: {name: "Maya", grade_level: "3rd", color: "sage"})

    assert_equal "[FILTERED]", filtered[:learner][:name]
    assert_equal "[FILTERED]", filtered[:learner][:grade_level]
    assert_equal "sage", filtered[:learner][:color]
  end
end
