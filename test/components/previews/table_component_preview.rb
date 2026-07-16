class TableComponentPreview < ViewComponent::Preview
  def default
    render sample_table
  end

  def striped
    render sample_table(striped: true, hoverable: true)
  end

  def compact
    render sample_table(density: :compact)
  end

  def sticky_header
    render sample_table(sticky_header: true, max_height: "max-h-96")
  end

  private

  def sample_table(**options)
    table = TableComponent.new(**options)
    table.with_column(label: "Name")
    table.with_column(label: "Role")
    table.with_row do |row|
      row.with_cell(primary: true) { "Avery Stone" }
      row.with_cell { "Owner" }
    end
    table.with_row do |row|
      row.with_cell(primary: true) { "Jordan Lee" }
      row.with_cell { "Editor" }
    end
    table
  end
end
