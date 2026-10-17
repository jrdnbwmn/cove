class ReplaceTimeOff
  Result = Data.define(:time_off, :error) do
    def success? = error.nil?
  end

  def initialize(time_off:)
    @time_off = time_off
  end

  def call
    time_off.school_year.with_lock do
      # AIDEV-NOTE: Re-query after locking; the modal's earlier conflicts may be stale.
      conflicts = time_off.overlaps.to_a
      if time_off.school_year.ended?
        time_off.errors.add(:base, SchoolYear::ENDED_ERROR)
      elsif conflicts.any?(&:started?)
        time_off.errors.add(:base, Break::STARTED_DELETE_ERROR)
      else
        conflicts.each(&:destroy!)
        time_off.save!
        return Result.new(time_off, nil)
      end
    end

    Result.new(time_off, time_off.errors.full_messages.to_sentence)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
    time_off.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == time_off
    Result.new(time_off, time_off.errors.full_messages.to_sentence)
  end

  private

  attr_reader :time_off
end
