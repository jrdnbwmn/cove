# frozen_string_literal: true

class AddTileComponent < ViewComponent::Base
  def initialize(text:, data: {}, classes: nil)
    super()
    @text = text
    @data = data
    @classes = classes
  end

  def button_classes
    [
      "flex h-full w-full flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-neutral-300 bg-transparent px-4 py-6 text-center text-sm font-medium text-muted-foreground transition-colors hover:border-neutral-400 hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
      @classes
    ].compact.reject(&:empty?).join(" ")
  end

  def button_attributes
    {type: "button", class: button_classes, data: data}
  end

  attr_reader :text, :data
end
