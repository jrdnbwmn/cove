class ToggleChipComponent < ViewComponent::Base
  def initialize(label:, name: nil, id: nil, value: "1", checked: false, disabled: false, error: nil, data: {})
    @label = label
    @name = name
    @id = id || "toggle_chip_#{SecureRandom.hex(4)}"
    @value = value
    @checked = checked
    @disabled = disabled
    @error = error
    @data = data
  end
end
