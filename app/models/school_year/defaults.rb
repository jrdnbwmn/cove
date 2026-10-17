module SchoolYear::Defaults
  extend ActiveSupport::Concern

  class_methods do
    def create_default_for!(account)
      account.with_lock do
        return account.school_year if account.school_year

        today = account.today
        calendar_year = today.year
        # AIDEV-NOTE: January through spring belongs to the previous August's year.
        calendar_year -= 1 if today < default_starts_on(calendar_year)
        calendar_year += 1 if today >= default_ends_on(calendar_year)

        starts_on = [today, default_starts_on(calendar_year)].max
        year = account.school_years.create!(starts_on: starts_on, ends_on: default_ends_on(calendar_year), school_weekdays: [1, 2, 3, 4, 5])
        create_default_breaks(year, calendar_year, today)
        first_school_day = (starts_on..year.ends_on).find { |date| year.school_day?(date) }
        year.update!(tracked_from: first_school_day) if account.school_years.count == 1
        year
      end
    end

    def default_starts_on(year)
      date = Date.new(year, 8, 15)
      date + (1 - date.wday) % 7
    end

    def default_ends_on(year)
      date = Date.new(year + 1, 5, 31)
      date - (date.wday - 5) % 7
    end

    def default_breaks_for(calendar_year)
      [["Thanksgiving", thanksgiving(calendar_year), thanksgiving(calendar_year) + 1],
        ["Winter holidays", Date.new(calendar_year, 12, 21), Date.new(calendar_year + 1, 1, 1)]]
    end

    private

    def create_default_breaks(year, calendar_year, today)
      default_breaks_for(calendar_year).each do |name, first_day, last_day|
        next if last_day < today

        year.breaks.create!(name: name, starts_on: [first_day, today].max, ends_on: last_day, source: "default")
      end
    end

    def thanksgiving(year)
      date = Date.new(year, 11, 1)
      date + (4 - date.wday) % 7 + 21
    end
  end
end
