require "test_helper"
require Rails.root.glob("db/migrate/*_normalize_learner_grade_levels.rb").first.to_s

class NormalizeLearnerGradeLevelsTest < ActiveSupport::TestCase
  test "existing active and archived grades convert once without changing other details" do
    connection = ActiveRecord::Base.connection
    constraint = "learners_grade_level_is_canonical"
    had_constraint = connection.check_constraint_exists?(:learners, name: constraint)
    connection.remove_check_constraint(:learners, name: constraint) if had_constraint
    labels = ["Pre-K", "Kindergarten", "1st grade", "2nd grade", "3rd grade", "4th grade", "5th grade", "6th grade", "7th grade", "8th grade", "9th grade", "10th grade", "11th grade", "12th grade"]
    cases = labels.to_h { |label| [label, label] }
    %w[PreK Pre-K Pre\ K Prekindergarten Pre-kindergarten].each { |value| cases[value] = "Pre-K" }
    %w[K Kinder Kindergarten].each { |value| cases[value] = "Kindergarten" }
    words = %w[first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth]
    labels.drop(2).each_with_index do |label, index|
      ordinal = label.split.first
      [(index + 1).to_s, ordinal, words[index], "Grade #{index + 1}", label, "#{words[index]} grade"].each do |value|
        cases[value] = label
        cases["  #{value.upcase.gsub(" ", "   ")}  "] = label
      end
    end
    [nil, "", "   ", "Freshman", "Sophomore", "Junior", "Senior", "13", "Grade third", "unknown"].each { |value| cases[value] = nil }
    rows = cases.each_with_index.map do |(value, expected), index|
      row = Learner.create!(account: accounts(:company), name: "Conversion #{index}", archived_at: Time.current)
      NormalizeLearnerGradeLevels::LearnerRow.find(row.id).update_columns(grade_level: value, archived_at: (Time.current if index.even?))
      [row, expected, row.reload.attributes.except("grade_level")]
    end

    2.times do
      NormalizeLearnerGradeLevels.new.migrate(:up)
      rows.each do |row, expected, details|
        expected.nil? ? assert_nil(row.reload.grade_level) : assert_equal(expected, row.reload.grade_level)
        assert_equal details, row.attributes.except("grade_level")
      end
    end
    NormalizeLearnerGradeLevels.new.migrate(:down)
    rows.each { |row, expected, _| expected.nil? ? assert_nil(row.reload.grade_level) : assert_equal(expected, row.reload.grade_level) }
  ensure
    if had_constraint
      require Rails.root.glob("db/migrate/*_enforce_learner_grade_levels.rb").first.to_s
      EnforceLearnerGradeLevels.new.migrate(:up)
    end
  end
end
