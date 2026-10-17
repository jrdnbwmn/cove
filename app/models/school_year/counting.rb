module SchoolYear::Counting
  extend ActiveSupport::Concern

  def school_day?(date)
    date.between?(starts_on, ends_on) && school_day_on?(date, breaks.to_a)
  end

  def school_days_count
    count_school_days(starts_on, ends_on)
  end

  def so_far_count
    count_school_days(starts_on, [account.today - 1, ends_on].min)
  end

  def to_go_count
    count_school_days([account.today, starts_on].max, ends_on)
  end

  def before_cove_count
    return 0 unless tracked_from

    count_school_days(starts_on, [tracked_from - 1, ends_on].min)
  end

  def added_days_if_ended_on(date)
    return 0 if date <= ends_on

    count_school_days(ends_on + 1, date)
  end

  private

  def count_school_days(first_date, last_date)
    time_off = breaks.to_a
    (first_date..last_date).count { |date| school_day_on?(date, time_off) }
  end

  def school_day_on?(date, time_off)
    historical_week = weekday_history.find { |entry| entry.fetch("through") >= date.iso8601 }
    weekdays = historical_week ? historical_week.fetch("days") : school_weekdays
    weekdays.include?(date.wday) && time_off.none? { |entry| date.between?(entry.starts_on, entry.ends_on) }
  end
end
