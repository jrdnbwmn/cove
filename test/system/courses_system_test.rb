require "application_system_test_case"

class CoursesSystemTest < ApplicationSystemTestCase
  setup do
    login_as users(:one), scope: :user
  end

  test "a parent can add, edit, and delete a class from the modal" do
    visit courses_path
    find("button", text: "Add class", match: :first).click

    within("dialog[open]") do
      fill_in "Name", with: "Algebra 1"
    end
    find("dialog[open] .ts-control").click
    assert_selector "dialog[open] > .ts-dropdown"
    find(".ts-dropdown [role='option']", text: "Math").click
    within("dialog[open]") do
      check "Maya"
      check "Theo"
      click_button "Add class"
    end

    assert_no_selector "dialog[open]"
    assert_text "Class added."
    assert_selector ".course-name", text: "Algebra 1"

    course = Course.order(:id).last
    assert_equal "Math", course.subject
    find("[data-course='#{course.id}']").click
    within("dialog[open]") do
      fill_in "Name", with: "Geometry"
      click_button "Save"
    end
    assert_text "Saved."

    find("[data-course='#{course.id}']").click
    within("dialog[open]") { click_link "Delete class" }
    within("dialog[open]") do
      assert_text "Delete Geometry?"
      click_button "Delete class"
    end
    assert_no_selector "dialog[open]"
    assert_text "Class deleted."
    assert_no_selector ".course-name", text: "Geometry"
  end

  test "a blank class name keeps the modal and entered values open" do
    visit courses_path
    find("button", text: "Add class", match: :first).click

    within("dialog[open]") do
      fill_in "Name", with: " "
      click_button "Add class"
      assert_text "Enter a name for this class."
      assert_field "Name", with: " "
    end
    assert_selector "dialog[open]"
  end

  test "completing a class from its menu moves it to Completed and reopening brings it back" do
    visit courses_path

    open_actions_menu("Algebra 1")
    click_button "Complete"

    assert_text "Algebra 1 is complete. Nice work."
    assert_no_selector ".course-name", text: "Algebra 1"
    click_link "Completed"
    assert_selector ".course-name", text: "Algebra 1"
    date = ApplicationController.helpers.friendly_date(courses(:one).reload.completed_at)
    assert_selector ".course-status-date", text: "Completed #{date}"

    open_actions_menu("Algebra 1")
    click_button "Reopen"

    assert_text "Algebra 1 is active again."
    assert_no_selector ".course-name", text: "Algebra 1"
    click_link "Active"
    assert_selector ".course-name", text: "Algebra 1"
  end

  test "archiving a class from its menu moves it to Archived and restoring brings it back" do
    visit courses_path

    open_actions_menu("Piano")
    click_button "Archive"

    assert_text "Piano archived."
    assert_no_selector ".course-name", text: "Piano"
    click_link "Archived"
    assert_selector ".course-name", text: "Piano"

    open_actions_menu("Piano")
    click_button "Restore"

    assert_text "Piano restored."
    click_link "Active"
    assert_selector ".course-name", text: "Piano"
  end

  test "Edit in a class menu opens the edit modal" do
    visit courses_path

    open_actions_menu("Algebra 1")
    click_button "Edit"

    within("dialog[open]") { assert_field "Name", with: "Algebra 1" }
  end

  test "deleting a class from its menu asks for confirmation first" do
    visit courses_path

    open_actions_menu("Nature study")
    click_button "Delete"

    within("dialog[open]") do
      assert_text "Delete Nature study?"
      click_button "Delete class"
    end

    assert_text "Class deleted."
    assert_no_selector ".course-name", text: "Nature study"
  end

  test "a completed class can be edited from its menu" do
    visit courses_path(status: "completed")

    open_actions_menu("Spanish 1")
    click_button "Edit"

    within("dialog[open]") { assert_field "Name", with: "Spanish 1" }
  end

  private

  def open_actions_menu(name)
    find("button[aria-label='Actions for #{name}']").click
    assert_selector "[role='menuitem']"
  end
end
