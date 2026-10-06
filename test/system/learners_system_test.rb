require "application_system_test_case"

class LearnersSystemTest < ApplicationSystemTestCase
  setup do
    login_as users(:one), scope: :user
  end

  test "a duplicate name shows its error inside the open modal" do
    open_slot
    visit learners_path
    open_add_modal

    within("dialog[open]") do
      fill_in "Name", with: "maya"
      click_button "Add learner"

      assert_text "You already have a learner named maya."
      assert_field "Name", with: "maya"
    end
    assert_selector "dialog[open]"
  end

  test "closing the add modal after a validation error still asks before discarding" do
    open_slot
    visit learners_path
    open_add_modal

    within("dialog[open]") do
      fill_in "Name", with: "maya"
      click_button "Add learner"
      assert_text "You already have a learner named maya."

      click_button "Cancel"
      assert_text "Discard your changes?"
    end
  end

  test "a parent can see the add learner title and close the modal" do
    open_slot
    visit learners_path
    open_add_modal

    within("dialog[open]") do
      assert_selector "h2", text: "Add learner"
      click_button "Close"
    end

    assert_no_selector "dialog[open]"
  end

  test "closing an untouched modal closes right away" do
    open_slot
    visit learners_path
    open_add_modal

    within("dialog[open]") do
      assert_selector "button", text: "Close"
      click_button "Cancel"
    end
    assert_no_selector "dialog[open]"
  end

  test "closing the add modal after typing asks before discarding" do
    open_slot
    visit learners_path
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
    assert_not Learner.exists?(name: "Nora")
  end

  test "adding a learner closes the modal, shows the learner and a toast" do
    open_slot
    visit learners_path
    open_add_modal

    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      fill_in "Grade level", with: "5th"
      click_button "Add learner"
    end

    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Nora"
    assert_text "Nora added."
    assert_current_path learners_path
  end

  test "editing a learner keeps validation in the modal and saves with a toast" do
    visit learners_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      fill_in "Name", with: "Theo"
      click_button "Save"
      assert_text "You already have a learner named Theo."

      fill_in "Name", with: "Maya R"
      click_button "Save"
    end

    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Maya R"
    assert_text "Saved."
  end

  test "archived learners are hidden until the Archived view is chosen and can be restored" do
    open_slot
    visit learners_path

    assert_no_selector "p", text: "Iris"

    click_link "Archived"

    assert_selector "nav[aria-label='Filter learners'] a[aria-current='page']", text: "Archived"
    assert_selector "p", text: "Iris"
    assert_no_selector "p", text: "Maya"
    open_actions_menu("Iris")
    click_button "Restore"

    assert_text "Iris restored."
    assert_selector "p", text: "Iris"
    assert_selector "p", text: "Maya"
    assert_no_selector "nav[aria-label='Filter learners']"
  end

  test "the Archived control only appears when a learner is archived" do
    learners(:archived).destroy!
    visit learners_path

    assert_selector "p", text: "Maya"
    assert_no_selector "nav[aria-label='Filter learners']"
  end

  test "a family whose learners are all archived still sees the Archived control" do
    learners(:one).archive!
    learners(:two).archive!
    visit learners_path

    assert_text "Add your first learner"
    assert_selector "nav[aria-label='Filter learners']"

    click_link "Archived"

    assert_selector "p", text: "Maya"
    assert_selector "p", text: "Theo"
    assert_selector "p", text: "Iris"
  end

  test "archiving from the edit modal moves the learner to the archived list" do
    visit learners_path
    open_edit_modal("Maya")

    within("dialog[open]") { click_button "Archive" }

    assert_text "Maya archived."
    assert_no_selector "dialog[open]"
    assert_no_selector "p", text: "Maya"
    click_link "Archived"
    assert_selector "p", text: "Maya"
  end

  test "deleting a learner asks for confirmation and removes them" do
    visit learners_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      click_link "Delete"
    end
    assert_selector "dialog[open]", count: 1
    within("dialog[open]") do
      assert_text "Delete Maya?"
      assert_no_selector "h2", text: "Edit Maya"
      click_button "Delete Maya"
    end

    assert_text "Maya deleted."
    assert_no_selector "dialog[open]"
    assert_no_selector "p", text: "Maya"
    assert_not Learner.exists?(ActiveRecord::FixtureSet.identify(:one))
  end

  test "cancelling Delete returns to the saved edit form without a discard prompt" do
    visit learners_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      fill_in "Grade level", with: "4th"
      click_link "Delete"
    end

    assert_selector "dialog[open]", count: 1
    within("dialog[open]") do
      assert_text "Delete Maya?"
      click_link "Cancel"
    end

    assert_selector "dialog[open]", count: 1
    within("dialog[open]") do
      assert_field "Grade level", with: learners(:one).grade_level
      click_button "Cancel"
    end
    assert_no_selector "dialog[open]"
  end

  test "cancelling Delete returns to a read-only learner in the same dialog" do
    logout(:user)
    login_as users(:downgraded), scope: :user
    visit learners_path

    within("[data-learner='#{learners(:read_only).id}']") { click_button "Casey" }
    within("dialog[open]") { click_link "Delete" }

    assert_selector "dialog[open]", count: 1
    within("dialog[open]") do
      assert_text "Delete Casey?"
      click_link "Cancel"
    end

    assert_selector "dialog[open]", count: 1
    within("dialog[open]") do
      assert_selector "h2", text: "Casey"
      assert_text "Casey can't be edited on Free. You can still archive or delete this learner."
    end
  end

  test "an archived learner can be deleted from the archived list" do
    visit learners_path(archived: 1)

    open_actions_menu("Iris")
    click_button "Delete"
    within("dialog[open]") do
      assert_text "Delete Iris?"
      click_button "Delete Iris"
    end

    assert_text "Iris deleted."
    assert_not Learner.exists?(ActiveRecord::FixtureSet.identify(:archived))
  end

  test "clicking a learner card opens their edit modal" do
    visit learners_path

    find("[data-learner='#{learners(:one).id}']").click

    assert_selector "dialog[open] input[name='learner[name]'][value='Maya']"
  end

  test "the actions menu is reachable by keyboard" do
    visit learners_path

    find("button", text: "Maya", exact_text: true).send_keys(:tab)
    assert_equal "Actions for Maya", evaluate_script("document.activeElement.getAttribute('aria-label')")
    page.send_keys(:enter)

    assert_selector "[role='menuitem']", text: "Archive"
    assert_selector "[role='menuitem']", text: "Delete"
  end

  test "archiving from the actions menu moves the learner to Archived" do
    visit learners_path

    open_actions_menu("Maya")
    click_button "Archive"

    assert_text "Maya archived."
    assert_no_selector "p", text: "Maya"
    click_link "Archived"
    assert_selector "p", text: "Maya"
  end

  test "deleting from the actions menu asks for confirmation and Cancel just closes it" do
    visit learners_path

    open_actions_menu("Maya")
    click_button "Delete"

    within("dialog[open]") do
      assert_text "Delete Maya?"
      assert_no_selector "input[name='learner[name]']"
      click_button "Cancel"
    end
    assert_no_selector "dialog[open]"
    assert_selector "p", text: "Maya"

    open_actions_menu("Maya")
    click_button "Delete"
    within("dialog[open]") { click_button "Delete Maya" }

    assert_text "Maya deleted."
    assert_not Learner.exists?(ActiveRecord::FixtureSet.identify(:one))
  end

  test "at the Free limit, Add learner explains the limit and links to plans" do
    visit learners_path

    find("button", text: "Add learner", match: :first).click

    within("dialog[open]") do
      assert_selector "h2", text: "Free includes 2 learners."
      assert_no_selector "input[name='learner[name]']"
      assert_link "See plans", href: pricing_path
    end
  end

  test "the limit modal is sized to its content on desktop, not the full window height" do
    visit learners_path

    find("button", text: "Add learner", match: :first).click

    assert_selector "dialog[open]"
    dialog_height = evaluate_script("document.querySelector('dialog[open]').getBoundingClientRect().height")
    window_height = evaluate_script("window.innerHeight")
    assert_operator dialog_height, :<, window_height / 2
  end

  test "at the Premium cap, Add learner explains the limit and offers Contact us" do
    account = accounts(:subscribed)
    account.update!(learner_limit: 3)
    3.times { |i| Learner.create!(account: account, name: "Learner #{i}") }
    logout(:user)
    login_as users(:subscribed), scope: :user
    visit learners_path

    find("button", text: "Add learner", match: :first).click

    within("dialog[open]") do
      assert_selector "h2", text: "Premium includes 3 learners."
      assert_no_selector "input[name='learner[name]']"
      assert_link "Contact us"
      assert_no_link "See plans"
    end
  end

  test "an archived learner has no Restore button while the family is at its limit" do
    visit learners_path(archived: 1)

    assert_selector "p", text: "Iris"
    assert_text "To restore a learner, archive one first"
    assert_no_button "Restore"
  end

  test "a stale Add modal keeps the typed name and shows the limit error inside the modal" do
    open_slot
    visit learners_path
    open_add_modal

    Learner.create!(account: accounts(:company), name: "Sam", color: "sky")

    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      click_button "Add learner"

      assert_text "Free includes 2 learners. Upgrade to Premium to add more."
      assert_field "Name", with: "Nora"
    end
    assert_selector "dialog[open]"
    assert_not Learner.exists?(name: "Nora")
  end

  test "a parent chooses which two learners remain editable on Free" do
    logout(:user)
    login_as users(:downgraded), scope: :user
    visit learners_path

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

    within("[data-learner='#{learners(:kept).id}']") { click_button "Avery" }
    within("dialog[open]") do
      assert_text "Avery can't be edited on Free. You can still archive or delete this learner."
    end
  end

  private

  # AIDEV-NOTE: the Free fixture family starts at its 2 active learner limit;
  # remove one active learner so tests that add or restore have an open slot.
  def open_slot
    learners(:two).destroy!
  end

  def open_add_modal
    find("button", text: "Add learner", match: :first).click
    assert_selector "dialog[open] input[name='learner[name]']"
  end

  def open_edit_modal(name)
    learner = Learner.find_by!(name: name)
    within("[data-learner='#{learner.id}']") { click_button name }
    assert_selector "dialog[open] input[name='learner[name]']"
  end

  def open_actions_menu(name)
    find("button[aria-label='Actions for #{name}']").click
    assert_selector "[role='menuitem']"
  end
end
