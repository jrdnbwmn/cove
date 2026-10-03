require "application_system_test_case"

class StudentsSystemTest < ApplicationSystemTestCase
  setup do
    login_as users(:one), scope: :user
  end

  test "a duplicate name shows its error inside the open modal" do
    visit students_path
    open_add_modal

    within("dialog[open]") do
      fill_in "Name", with: "maya"
      click_button "Add student"

      assert_text "You already have a student named maya."
      assert_field "Name", with: "maya"
    end
    assert_selector "dialog[open]"
  end

  test "a parent can see the add student title and close the modal" do
    visit students_path
    open_add_modal

    within("dialog[open]") do
      assert_selector "h2", text: "Add student"
      click_button "Close"
    end

    assert_no_selector "dialog[open]"
  end

  test "adding a student closes the modal, shows the student and a toast" do
    visit students_path
    open_add_modal

    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      fill_in "Grade level", with: "5th"
      click_button "Add student"
    end

    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Nora"
    assert_text "Nora added."
    assert_current_path students_path
  end

  test "editing a student keeps validation in the modal and saves with a toast" do
    visit students_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      fill_in "Name", with: "Theo"
      click_button "Save"
      assert_text "You already have a student named Theo."

      fill_in "Name", with: "Maya R"
      click_button "Save"
    end

    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Maya R"
    assert_text "Saved."
  end

  test "archived students are hidden until toggled and can be restored" do
    visit students_path

    assert_no_selector "h2", text: "Archived"
    assert_no_selector "p", text: "Iris"

    click_link "Show archived (1)"

    assert_selector "h2", text: "Archived"
    assert_selector "p", text: "Iris"
    click_button "Restore"

    assert_text "Iris restored."
    assert_no_selector "h2", text: "Archived"
    assert_selector "p", text: "Iris"
  end

  test "archiving from the edit modal moves the student to the archived list" do
    visit students_path
    open_edit_modal("Maya")

    within("dialog[open]") { click_button "Archive Maya" }

    assert_text "Maya archived."
    assert_no_selector "dialog[open]"
    assert_no_selector "p", text: "Maya"
    click_link "Show archived (2)"
    assert_selector "p", text: "Maya"
  end

  test "deleting a student asks for confirmation and removes them" do
    visit students_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      click_link "Delete Maya"
      assert_text "Delete Maya?"
      click_button "Delete Maya"
    end

    assert_text "Maya deleted."
    assert_no_selector "dialog[open]"
    assert_no_selector "p", text: "Maya"
    assert_not Student.exists?(ActiveRecord::FixtureSet.identify(:one))
  end

  test "an archived student can be deleted from the archived list" do
    visit students_path(archived: 1)

    within("section[aria-labelledby='archived-heading']") { click_button "Delete" }
    within("dialog[open]") do
      assert_text "Delete Iris?"
      click_button "Delete Iris"
    end

    assert_text "Iris deleted."
    assert_not Student.exists?(ActiveRecord::FixtureSet.identify(:archived))
  end

  private

  def open_add_modal
    find("button", text: "Add student", match: :first).click
    assert_selector "dialog[open] input[name='student[name]']"
  end

  def open_edit_modal(name)
    student = Student.find_by!(name: name)
    within("[data-student='#{student.id}']") { click_button "Edit" }
    assert_selector "dialog[open] input[name='student[name]']"
  end
end
