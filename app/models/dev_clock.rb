# AIDEV-NOTE: A shared date override changes school-day logic without changing system timestamps.
class DevClock
  def self.path
    Rails.root.join("tmp/dev_today")
  end

  def self.today
    return unless Rails.env.development?

    Date.iso8601(path.read.strip)
  rescue SystemCallError, IOError, ArgumentError
    nil
  end

  def self.set(date)
    path.write(date.iso8601)
  end

  def self.clear
    path.delete if path.exist?
  end
end
