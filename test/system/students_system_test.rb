require "application_system_test_case"

class StudentsSystemTest < ApplicationSystemTestCase
  setup do
    login_as users(:one), scope: :user
  end

  test "a duplicate name shows its error inside the open modal" do
    open_slot
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
    open_slot
    visit students_path
    open_add_modal

    within("dialog[open]") do
      assert_selector "h2", text: "Add student"
      click_button "Close"
    end

    assert_no_selector "dialog[open]"
  end

  test "closing an untouched modal closes right away" do
    open_slot
    visit students_path
    open_add_modal

    within("dialog[open]") do
      assert_selector "button", text: "Close"
      click_button "Cancel"
    end
    assert_no_selector "dialog[open]"
  end

  test "closing the add modal after typing asks before discarding" do
    open_slot
    visit students_path
    open_add_modal

    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      click_button "Cancel"

      assert_text "Discard your changes?"
      click_button "Keep editing"
      assert_field "Name", with: "Nora"

      click_button "Cancel"
      click_button "Discard"
    end

    assert_no_selector "dialog[open]"
    assert_not Student.exists?(name: "Nora")
  end

  test "adding a student closes the modal, shows the student and a toast" do
    open_slot
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
    open_slot
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

    within("dialog[open]") { click_button "Archive" }

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
      click_link "Delete"
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

  test "a family at its Free limit sees the upgrade prompt instead of Add student" do
    visit students_path

    assert_text "Free includes 2 students."
    assert_link "Upgrade to Premium"
    assert_no_selector "button", text: "Add student"
  end

  test "an archived student has no Restore button while the family is at its limit" do
    visit students_path(archived: 1)

    assert_selector "p", text: "Iris"
    assert_text "To restore a student, archive one first"
    assert_no_button "Restore"
  end

  test "a stale Add modal keeps the typed name and shows the limit error inside the modal" do
    open_slot
    visit students_path
    open_add_modal

    Student.create!(account: accounts(:company), name: "Sam", color: "sky")

    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      click_button "Add student"

      assert_text "Free includes 2 students. Upgrade to Premium to add more."
      assert_field "Name", with: "Nora"
    end
    assert_selector "dialog[open]"
    assert_not Student.exists?(name: "Nora")
  end

  test "a parent chooses which two students remain editable on Free" do
    logout(:user)
    login_as users(:downgraded), scope: :user
    visit students_path

    click_button "Change"

    within("dialog[open]") do
      assert_checked_field "Avery"
      assert_checked_field "Blake"
      assert_field "Casey", disabled: true
      assert_button "Save", disabled: false

      uncheck "Avery"

      assert_field "Casey", disabled: false
      assert_button "Save", disabled: true

      check "Casey"

      assert_field "Avery", disabled: true
      assert_button "Save", disabled: false
      click_button "Save"
    end

    assert_no_selector "dialog[open]"
    assert_text "Saved. Blake and Casey stay editable."

    within("[data-student='#{students(:kept).id}']") { click_button "View" }
    within("dialog[open]") do
      assert_text "Avery can't be edited on Free. You can still archive or delete this student."
    end
  end

  private

  # AIDEV-NOTE: the Free fixture family starts at its 2 active student limit;
  # remove one active student so tests that add or restore have an open slot.
  def open_slot
    students(:two).destroy!
  end

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
