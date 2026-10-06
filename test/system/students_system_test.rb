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

  test "archived students are hidden until the Archived view is chosen and can be restored" do
    open_slot
    visit students_path

    assert_no_selector "p", text: "Iris"

    click_link "Archived"

    assert_selector "nav[aria-label='Filter students'] a[aria-current='true']", text: "Archived"
    assert_selector "p", text: "Iris"
    assert_no_selector "p", text: "Maya"
    open_actions_menu("Iris")
    click_button "Restore"

    assert_text "Iris restored."
    assert_selector "p", text: "Iris"
    assert_selector "p", text: "Maya"
    assert_no_selector "nav[aria-label='Filter students']"
  end

  test "the Archived control only appears when a student is archived" do
    students(:archived).destroy!
    visit students_path

    assert_selector "p", text: "Maya"
    assert_no_selector "nav[aria-label='Filter students']"
  end

  test "a family whose students are all archived still sees the Archived control" do
    students(:one).archive!
    students(:two).archive!
    visit students_path

    assert_text "Add your first student"
    assert_selector "nav[aria-label='Filter students']"

    click_link "Archived"

    assert_selector "p", text: "Maya"
    assert_selector "p", text: "Theo"
    assert_selector "p", text: "Iris"
  end

  test "archiving from the edit modal moves the student to the archived list" do
    visit students_path
    open_edit_modal("Maya")

    within("dialog[open]") { click_button "Archive" }

    assert_text "Maya archived."
    assert_no_selector "dialog[open]"
    assert_no_selector "p", text: "Maya"
    click_link "Archived"
    assert_selector "p", text: "Maya"
  end

  test "deleting a student asks for confirmation and removes them" do
    visit students_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      click_button "Delete"
      assert_text "Delete Maya?"
      click_button "Delete Maya"
    end

    assert_text "Maya deleted."
    assert_no_selector "dialog[open]"
    assert_no_selector "p", text: "Maya"
    assert_not Student.exists?(ActiveRecord::FixtureSet.identify(:one))
  end

  test "cancelling Delete returns to the open edit modal with its fields intact" do
    visit students_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      fill_in "Grade level", with: "4th"
      click_button "Delete"
    end

    assert_selector "dialog[open]", count: 2
    within(all("dialog[open]").last) do
      assert_text "Delete Maya?"
      click_button "Cancel"
    end

    assert_selector "dialog[open]", count: 1
    within("dialog[open]") { assert_field "Grade level", with: "4th" }

    within("dialog[open]") { click_button "Delete" }
    assert_selector "dialog[open]", count: 2
    page.send_keys(:escape)

    assert_selector "dialog[open]", count: 1
    within("dialog[open]") { assert_field "Grade level", with: "4th" }
  end

  test "an archived student can be deleted from the archived list" do
    visit students_path(archived: 1)

    open_actions_menu("Iris")
    click_button "Delete"
    within("dialog[open]") do
      assert_text "Delete Iris?"
      click_button "Delete Iris"
    end

    assert_text "Iris deleted."
    assert_not Student.exists?(ActiveRecord::FixtureSet.identify(:archived))
  end

  test "clicking a student card opens their edit modal" do
    visit students_path

    find("[data-student='#{students(:one).id}']").click

    assert_selector "dialog[open] input[name='student[name]'][value='Maya']"
  end

  test "the actions menu is reachable by keyboard" do
    visit students_path

    find("button", text: "Maya", exact_text: true).send_keys(:tab)
    assert_equal "Actions for Maya", evaluate_script("document.activeElement.getAttribute('aria-label')")
    page.send_keys(:enter)

    assert_selector "[role='menuitem']", text: "Archive"
    assert_selector "[role='menuitem']", text: "Delete"
  end

  test "archiving from the actions menu moves the student to Archived" do
    visit students_path

    open_actions_menu("Maya")
    click_button "Archive"

    assert_text "Maya archived."
    assert_no_selector "p", text: "Maya"
    click_link "Archived"
    assert_selector "p", text: "Maya"
  end

  test "deleting from the actions menu asks for confirmation and Cancel just closes it" do
    visit students_path

    open_actions_menu("Maya")
    click_button "Delete"

    within("dialog[open]") do
      assert_text "Delete Maya?"
      assert_no_selector "input[name='student[name]']"
      click_button "Cancel"
    end
    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Maya"

    open_actions_menu("Maya")
    click_button "Delete"
    within("dialog[open]") { click_button "Delete Maya" }

    assert_text "Maya deleted."
    assert_not Student.exists?(ActiveRecord::FixtureSet.identify(:one))
  end

  test "at the Free limit, Add student explains the limit and links to plans" do
    visit students_path

    find("button", text: "Add student", match: :first).click

    within("dialog[open]") do
      assert_selector "h2", text: "Free includes 2 students."
      assert_no_selector "input[name='student[name]']"
      assert_link "See plans", href: pricing_path
    end
  end

  test "the limit modal is sized to its content on desktop, not the full window height" do
    visit students_path

    find("button", text: "Add student", match: :first).click

    assert_selector "dialog[open]"
    dialog_height = evaluate_script("document.querySelector('dialog[open]').getBoundingClientRect().height")
    window_height = evaluate_script("window.innerHeight")
    assert_operator dialog_height, :<, window_height / 2
  end

  test "at the Premium cap, Add student explains the limit and offers Contact us" do
    account = accounts(:subscribed)
    account.update!(student_limit: 3)
    3.times { |i| Student.create!(account: account, name: "Student #{i}") }
    logout(:user)
    login_as users(:subscribed), scope: :user
    visit students_path

    find("button", text: "Add student", match: :first).click

    within("dialog[open]") do
      assert_selector "h2", text: "Premium includes 3 students."
      assert_no_selector "input[name='student[name]']"
      assert_link "Contact us"
      assert_no_link "See plans"
    end
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

    within("[data-student='#{students(:kept).id}']") { click_button "Avery" }
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
    within("[data-student='#{student.id}']") { click_button name }
    assert_selector "dialog[open] input[name='student[name]']"
  end

  def open_actions_menu(name)
    find("button[aria-label='Actions for #{name}']").click
    assert_selector "[role='menuitem']"
  end
end
