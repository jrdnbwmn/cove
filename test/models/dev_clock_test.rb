require "test_helper"
require "tmpdir"

class DevClockTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("cove-clock")
    @path = Pathname.new(@directory).join("dev_today")
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test "the pretend date persists is replaced and can be cleared even when absent" do
    with_clock do
      assert_nil DevClock.today
      DevClock.set(Date.new(2026, 10, 14))
      assert_equal "2026-10-14", @path.read
      assert_equal Date.new(2026, 10, 14), DevClock.today
      DevClock.set(Date.new(2027, 2, 1))
      assert_equal Date.new(2027, 2, 1), DevClock.today
      DevClock.clear
      assert_nil DevClock.today
      assert_nothing_raised { DevClock.clear }
    end
  end

  test "missing junk invalid and unreadable clock files use the real clock" do
    with_clock do
      assert_nil DevClock.today
      ["junk", "2026-02-30", "", "2026-10-14 extra"].each do |content|
        @path.write(content)
        assert_nil DevClock.today
      end
      @path.delete
      @path.mkdir
      assert_nil DevClock.today
    end
  end

  test "test staging and production never read an override" do
    @path.write("2026-10-14")
    %w[test staging production].each do |environment|
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(environment)) do
        DevClock.stub(:path, @path) { assert_nil DevClock.today }
      end
    end
  end

  private

  def with_clock(&block)
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      DevClock.stub(:path, @path, &block)
    end
  end
end
