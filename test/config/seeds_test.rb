require "test_helper"
require "tmpdir"

class SeedsTest < ActiveSupport::TestCase
  SEEDS_FILE = Rails.root.join("db/seeds.rb")
  DEMO_EMAILS = "%@cove.test"

  setup do
    @clock_directory = Dir.mktmpdir("cove-seed-clock")
    @clock_path = Pathname.new(@clock_directory).join("dev_today")
  end

  teardown do
    FileUtils.remove_entry(@clock_directory)
  end

  %w[staging production].each do |environment|
    test "#{environment} does not create demo seed data" do
      environment_inquirer = ActiveSupport::EnvironmentInquirer.new(environment)

      assert_no_difference [
        -> { User.count },
        -> { Account.count },
        -> { AccountUser.count },
        -> { Plan.count },
        -> { Course.count },
        -> { SchoolYear.count },
        -> { Break.count }
      ] do
        load_seeds(environment_inquirer)
      end

      assert_not User.where("email LIKE ?", DEMO_EMAILS).exists?
    end
  end

  test "development reseeding corrects Premium prices without duplicating plans" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    load_seeds(environment_inquirer)

    Plan.find_by!(fake_processor_id: "premium_monthly").update!(amount: 900)
    Plan.find_by!(fake_processor_id: "premium_yearly").update!(amount: 8400)

    load_seeds(environment_inquirer)

    seeded = Plan.where(fake_processor_id: %w[premium_monthly premium_yearly])
    assert_equal 2, seeded.count

    monthly = seeded.visible.where(name: "Premium", interval: "month", fake_processor_id: "premium_monthly")
    yearly = seeded.visible.where(name: "Premium", interval: "year", fake_processor_id: "premium_yearly")
    assert_equal 1, monthly.count
    assert_equal 1, yearly.count
    assert_equal 1200, monthly.first.amount
    assert_equal 12000, yearly.first.amount
    assert_equal [0, 0], [monthly.first.trial_period_days, yearly.first.trial_period_days]

    assert_not Plan.exists?(fake_processor_id: "cove_dev")
    assert_equal "premium_monthly", User.find_by!(email: "subscribed@cove.test").family.payment_processor.subscription.processor_plan
  end

  test "development seeds one two-parent family and one flat-rate subscribed family" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    load_seeds(environment_inquirer)

    family = Account.find_by!(name: "Cove Family")
    assert_equal 2, family.account_users_count
    assert_equal 2, family.parents.count
    assert_equal 1, User.find_by!(email: "subscribed@cove.test").family.payment_processor.subscription.quantity
  end

  test "development seeds three demo classes without duplicate enrollments" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    load_seeds(environment_inquirer)
    load_seeds(environment_inquirer)

    family = Account.find_by!(name: "Cove Family")
    assert_equal 3, family.courses.count

    algebra = family.courses.find_by!(name: "Algebra 1")
    piano = family.courses.find_by!(name: "Piano")
    nature_study = family.courses.find_by!(name: "Nature study")

    assert_equal "Math", algebra.subject
    assert_equal ["Maya", "Theo"], algebra.learners.ordered.pluck(:name)
    assert_equal "Arts", piano.subject
    assert_equal ["Maya"], piano.learners.pluck(:name)
    assert_nil nature_study.subject
    assert_empty nature_study.learners
    assert_equal 3, [algebra, piano, nature_study].sum { |course| course.enrollments.count }
  end

  test "development seeds one complimentary Premium tester family without billing records" do
    environment_inquirer = ActiveSupport::EnvironmentInquirer.new("development")

    load_seeds(environment_inquirer)
    load_seeds(environment_inquirer)

    testers = User.where(email: "tester@cove.test")
    assert_equal 1, testers.count

    tester = testers.sole
    assert_equal "Tina Tester", tester.name
    assert tester.valid_password?("password")
    assert_not_nil tester.confirmed_at
    assert_not_nil tester.accepted_terms_at

    family = tester.family
    assert family.complimentary_premium?
    assert_equal "Dev seed: complimentary Premium tester", family.complimentary_premium_note
    assert_empty family.pay_customers
    assert_empty family.pay_subscriptions
  end

  [["autumn", "2026-10-14", 2026],
    ["spring", "2027-03-10", 2026],
    ["summer", "2027-07-10", 2026],
    ["August start", "2026-08-17", 2026]].each do |season, pretend_date, calendar_year|
    test "development seeds separate school year scenarios in #{season}" do
      @clock_path.write(pretend_date)
      today = Date.iso8601(pretend_date)
      load_seeds

      families = %w[new midyear away].map do |scenario|
        user = User.find_by!(email: "#{scenario}@cove.test")
        assert user.valid_password?("password")
        assert_not_nil user.confirmed_at
        assert_not_nil user.accepted_terms_at
        user.family
      end
      assert_equal ["New Family", "Mid-year Family", "Away Family"], families.map(&:name)
      assert_equal 3, families.map(&:id).uniq.count
      assert_equal [1, 1, 1], families.map { |family| family.parents.count }
      assert_equal [1, 1, 1], families.map { |family| family.school_years.count }

      new_year = families.first.school_year
      expected_new_start = (season == "summer") ? SchoolYear.default_starts_on(2027) : today
      assert_equal expected_new_start, new_year.starts_on
      assert_equal SchoolYear.default_ends_on((season == "summer") ? 2027 : calendar_year), new_year.ends_on
      assert_equal (new_year.starts_on..new_year.ends_on).find { |day| new_year.school_day?(day) }, new_year.tracked_from
      expected_new_breaks = SchoolYear.default_breaks_for((season == "summer") ? 2027 : calendar_year).filter_map do |name, first, last|
        [name, [first, today].max, last] unless last < today
      end
      assert_equal expected_new_breaks, new_year.breaks.ordered.pluck(:name, :starts_on, :ends_on)

      families.drop(1).each do |family|
        year = family.school_year
        assert_equal SchoolYear.default_starts_on(calendar_year), year.starts_on
        assert_equal SchoolYear.default_ends_on(calendar_year), year.ends_on
        assert_equal [1, 2, 3, 4, 5], year.school_weekdays
        assert_empty year.weekday_history
        assert_equal (year.starts_on..year.ends_on).find { |day| year.school_day?(day) }, year.tracked_from
        assert_equal SchoolYear.default_breaks_for(calendar_year), year.breaks.where(source: "default").ordered.pluck(:name, :starts_on, :ends_on)
        past_entries = year.breaks.where(source: "added")
        if today == year.starts_on
          assert_empty past_entries
        else
          assert_equal 1, past_entries.count
          entry = past_entries.sole
          assert_operator entry.starts_on, :>=, year.starts_on
          assert_operator entry.ends_on, :<, today
          assert_operator entry.ends_on, :<=, year.ends_on
          assert_empty year.breaks.where.not(id: entry.id).overlapping(entry.starts_on, entry.ends_on)
        end
      end
    end
  end

  test "reseeding preserves school year scenarios after the pretend date changes" do
    @clock_path.write("2026-10-14")
    load_seeds
    families = User.where(email: %w[new@cove.test midyear@cove.test away@cove.test]).map(&:family)
    assert_equal 3, families.count
    years = families.map { |family| family.school_year.attributes }
    entries = families.map { |family| family.school_year.breaks.ordered.map(&:attributes) }

    @clock_path.write("2027-07-10")
    assert_no_difference [-> { User.count }, -> { Account.count }, -> { SchoolYear.count }, -> { Break.count }] do
      load_seeds
    end
    assert_equal years, families.map { |family| family.reload.school_year.attributes }
    assert_equal entries, families.map { |family| family.school_year.breaks.ordered.map(&:attributes) }
  end

  test "reseeding restores a missing scenario year without duplicating its family" do
    @clock_path.write("2027-07-10")
    load_seeds
    family = User.find_by!(email: "midyear@cove.test").family
    family.school_year.destroy!

    assert_no_difference [-> { User.count }, -> { Account.count }] do
      assert_difference "SchoolYear.count", 1 do
        load_seeds
      end
    end
    year = family.reload.school_year
    assert_equal Date.new(2026, 8, 17), year.starts_on
    assert_equal 3, year.breaks.count
  end

  private

  def load_seeds(environment = ActiveSupport::EnvironmentInquirer.new("development"))
    DevClock.stub(:path, @clock_path) do
      Rails.stub(:env, environment) { load SEEDS_FILE }
    end
  end
end
