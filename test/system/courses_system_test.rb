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
      find(".ts-control").click
      find(".ts-dropdown [role='option']", text: "Math").click
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
end
