class DevClockStripComponent < ViewComponent::Base
  def initialize(date: DevClock.today)
    @date = date
  end

  def render?
    Rails.env.development? && @date.present?
  end
end
