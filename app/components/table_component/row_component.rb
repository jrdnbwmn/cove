# frozen_string_literal: true

class TableComponent
  class RowComponent < ViewComponent::Base
    renders_many :cells, lambda { |align: :left, primary: false, classes: nil|
      TableComponent::CellComponent.new(align: align, primary: primary, density: @density, classes: classes)
    }

    def initialize(classes: nil, striped: false, hoverable: false, density: :default)
      super()
      @classes = classes
      @striped = striped
      @hoverable = hoverable
      @density = density
    end

    def row_classes
      classes = []
      classes << "hover:bg-neutral-50 dark:hover:bg-neutral-800/50" if @hoverable
      classes << "border-b border-neutral-200 last:border-b-0 dark:border-neutral-800"
      classes << @classes if @classes
      classes.compact.reject(&:empty?).join(" ")
    end

    attr_reader :striped, :hoverable, :density
  end
end
