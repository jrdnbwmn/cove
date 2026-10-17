module SchoolYearsHelper
  def school_weekdays_label(weekdays)
    days = weekdays.sort_by { |day| (day + 6) % 7 }
    labels = days.map { |day| I18n.t("date.abbr_day_names")[day] }
    consecutive = days.each_cons(2).all? { |first, second| (first + 1) % 7 == second }
    (days.length > 1 && consecutive) ? "#{labels.first}–#{labels.last}" : labels.join(", ")
  end

  # Monday first, as parents read a week. Values are Ruby's wday (Sunday is 0).
  def school_weekday_options
    %w[Mon Tue Wed Thu Fri Sat Sun].each_with_index.map { |label, index| [label, (index + 1) % 7] }
  end

  def time_off_submit_label(time_off, conflicts, replaceable)
    return (conflicts.one? ? "Replace it" : "Replace them") if replaceable

    time_off.persisted? ? "Save" : "Add time off"
  end

  def school_year_summary(year)
    progress = if year.ended?
      "This year has ended."
    elsif year.starts_on > year.account.today
      "Starts #{l(year.starts_on, format: :friendly_short)}"
    else
      counts = "#{year.so_far_count} so far, #{year.to_go_count} to go"
      before_cove = year.before_cove_count
      counts += ", including #{before_cove} before Cove" if before_cove.positive?
      counts
    end

    [school_weekdays_label(year.school_weekdays), friendly_date_range(year.starts_on, year.ends_on, today: year.account.today),
      pluralize(year.school_days_count, "school day"), progress].join(" · ")
  end
end
