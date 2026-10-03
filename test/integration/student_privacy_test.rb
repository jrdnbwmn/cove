require "test_helper"

class StudentPrivacyTest < ActiveSupport::TestCase
  test "student name and grade level are filtered from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(student: {name: "Maya", grade_level: "3rd", color: "sage"})

    assert_equal "[FILTERED]", filtered[:student][:name]
    assert_equal "[FILTERED]", filtered[:student][:grade_level]
    assert_equal "sage", filtered[:student][:color]
  end
end
