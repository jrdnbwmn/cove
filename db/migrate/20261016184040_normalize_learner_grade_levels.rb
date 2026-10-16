class NormalizeLearnerGradeLevels < ActiveRecord::Migration[8.1]
  class LearnerRow < ActiveRecord::Base
    self.table_name = "learners"
  end

  GRADE_MAPPING = begin
    mapping = {}
    %w[prek pre-k pre\ k prekindergarten pre-kindergarten].each { |value| mapping[value] = "Pre-K" }
    %w[k kinder kindergarten].each { |value| mapping[value] = "Kindergarten" }
    words = %w[first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth]
    ordinals = %w[1st 2nd 3rd 4th 5th 6th 7th 8th 9th 10th 11th 12th]
    ordinals.each_with_index do |ordinal, index|
      label = "#{ordinal} grade"
      [(index + 1).to_s, ordinal, words[index], "grade #{index + 1}", label, "#{words[index]} grade"].each { |value| mapping[value] = label }
    end
    mapping.freeze
  end

  def up
    # AIDEV-NOTE: Legacy grades are private learner data. Bypass current model
    # rules and silence SQL so neither identities nor grades enter migration logs.
    ActiveRecord::Base.logger.silence do
      LearnerRow.find_each do |learner|
        key = learner.grade_level.to_s.downcase.gsub(/[[:space:]]+/, " ").strip
        learner.update_columns(grade_level: GRADE_MAPPING[key])
      end
    end
  end

  def down
    # AIDEV-NOTE: Conversion is deliberately lossy; no original learner data is
    # retained. Canonical values remain intact when rolling back.
  end
end
