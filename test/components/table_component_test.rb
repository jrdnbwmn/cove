require "test_helper"
require "view_component/test_case"

class TableComponentTest < ViewComponent::TestCase
  test "renders accessible columns and cells" do
    render_inline(TableComponent.new) do |table|
      table.with_column(label: "Name")
      table.with_row do |row|
        row.with_cell(primary: true) { "Avery Stone" }
      end
    end

    assert_selector "th[scope='col']", text: "Name"
    assert_selector "td", text: "Avery Stone"
  end

  test "renders the striped preview" do
    render_preview(:striped)

    assert_selector "table"
  end
end
