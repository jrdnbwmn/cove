require "application_system_test_case"

class LearnersSystemTest < ApplicationSystemTestCase
  setup do
    login_as users(:one), scope: :user
  end

  test "adding the first learner keeps modal headings and labels left aligned" do
    Learner.where(account: accounts(:company)).destroy_all
    visit learners_path
    click_button "Add learner"

    assert_selector "dialog[open] input[name='learner[name]']"
    within("dialog[open]") do
      assert_equal "left", find("h2").evaluate_script("getComputedStyle(this).textAlign")
      assert_equal "left", find("label[for='learner_name']").evaluate_script("getComputedStyle(this).textAlign")
    end
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
      assert_no_field "Name"
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
      wait_for_turbo_navigation { click_button "Add learner" }
    end

    assert_current_path learners_path
    assert_no_selector "dialog[open]"
    assert_text "Nora added."
    assert_selector "[data-learner]", text: "Nora"
  end

  test "editing a learner keeps validation in the modal and saves with a toast" do
    visit learners_path
    open_edit_modal("Maya")

    within("dialog[open]") do
      fill_in "Name", with: "Theo"
      click_button "Save"
      assert_text "You already have a learner named Theo."

      fill_in "Name", with: "Maya R"
      wait_for_turbo_navigation { click_button "Save" }
    end

    assert_no_selector "dialog[open]"
    assert_text "Saved."
    assert_selector "[data-learner]", text: "Maya R"
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

    within("dialog[open]") { wait_for_turbo_navigation { click_button "Archive" } }

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
      wait_for_turbo_navigation { click_button "Delete Maya" }
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

  test "cancelling Delete returns to editing after downgrade in the same dialog" do
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
      assert_selector "h2", text: "Edit Casey"
      assert_field "Name", with: "Casey"
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
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Delete Maya" } }

    assert_text "Maya deleted."
    assert_not Learner.exists?(ActiveRecord::FixtureSet.identify(:one))
  end

  test "at the family cap, Add learner offers Email us" do
    fill_to_capacity(accounts(:company))
    visit learners_path

    click_header_add_learner

    within("dialog[open]") do
      assert_selector "h2", text: "Adding more than 15 learners?"
      assert_no_selector "input[name='learner[name]']"
      assert_link "Email us"
    end
  end

  test "the limit modal is sized to its content on desktop, not the full window height" do
    fill_to_capacity(accounts(:company))
    visit learners_path

    click_header_add_learner

    assert_selector "dialog[open]"
    dialog_height = evaluate_script("document.querySelector('dialog[open]').getBoundingClientRect().height")
    window_height = evaluate_script("window.innerHeight")
    assert_operator dialog_height, :<, window_height / 2
  end

  test "at the Premium cap, Add learner explains the limit and offers Email us" do
    account = accounts(:subscribed)
    account.update!(learner_limit: 15)
    15.times { |i| Learner.create!(account: account, name: "Learner #{i}") }
    logout(:user)
    login_as users(:subscribed), scope: :user
    visit learners_path

    click_header_add_learner

    within("dialog[open]") do
      assert_selector "h2", text: "Adding more than 15 learners?"
      assert_no_selector "input[name='learner[name]']"
      assert_link "Email us"
      assert_no_link "See plans"
    end
  end

  test "an archived learner has no Restore button while the family is at its limit" do
    fill_to_capacity(accounts(:company))
    visit learners_path(archived: 1)

    assert_selector "p", text: "Iris"
    assert_text "To restore a learner, archive one first"
    assert_no_button "Restore"
  end

  test "a stale Add modal keeps the typed name and shows the limit error inside the modal" do
    open_slot
    visit learners_path
    open_add_modal

    fill_to_capacity(accounts(:company))

    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      click_button "Add learner"

      assert_text "To add more than 15 learners, send us a quick note and we'll raise your limit."
      assert_field "Name", with: "Nora"
    end
    assert_selector "dialog[open]"
    assert_not Learner.exists?(name: "Nora")
  end

  test "a parent can open the add learner form from the inline tile" do
    open_slot
    visit learners_path

    within(inline_add_tile) { click_button "Add learner" }

    assert_selector "dialog[open] input[name='learner[name]']"
  end

  test "reaching the learner limit switches the inline tile to the limit modal" do
    fill_to_capacity(accounts(:company), slots: 1)
    visit learners_path

    within(inline_add_tile) { click_button "Add learner" }
    within("dialog[open]") do
      fill_in "Name", with: "Nora"
      wait_for_turbo_navigation { click_button "Add learner" }
    end

    assert_current_path learners_path
    assert_text "Nora added."
    assert_selector limit_tile
    assert_no_selector "#{limit_tile}[data-ui-modal-turbo-frame-src-value]"

    within(limit_tile) { click_button "Add learner" }
    within("dialog[open]") do
      assert_selector "h2", text: "Adding more than 15 learners?"
      assert_no_selector "input[name='learner[name]']"
    end
  end

  test "downgrading a family with five learners leaves every learner editable" do
    family = accounts(:downgraded)
    family.update!(complimentary_premium: true, complimentary_premium_note: "Test access")
    assert_equal 5, family.learners.active.count
    family.update!(complimentary_premium: false)
    logout(:user)
    login_as users(:downgraded), scope: :user
    visit learners_path
    assert_no_text "Read-only"
    assert_no_button "Change"
    family.learners.active.each do |learner|
      within("[data-learner='#{learner.id}']") { click_button learner.name }
      within("dialog[open]") do
        assert_field "Name", with: learner.name
        fill_in "Grade level", with: "4th"
        wait_for_turbo_navigation { click_button "Save" }
      end
      assert_no_selector "dialog[open]"
      assert_equal "4th", learner.reload.grade_level
    end
  end

  private

  def fill_to_capacity(account, slots: 0)
    (account.learners.active.count...(account.learner_limit - slots)).each do |i|
      Learner.create!(account: account, name: "Learner #{i}")
    end
  end

  # Keep one baseline learner for tests exercising add/restore flows.
  def open_slot
    learners(:two).destroy!
  end

  def open_add_modal
    click_header_add_learner
    assert_selector "dialog[open] input[name='learner[name]']"
  end

  def click_header_add_learner
    within("[data-page-header-actions]") { click_button "Add learner" }
  end

  def inline_add_tile
    ".grid > [data-ui-modal-turbo-frame-src-value='#{new_learner_path}'].h-full:last-child"
  end

  def limit_tile
    ".grid > [data-controller~='ui-modal'].h-full:last-child"
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

  test "a learner card's color dot lines up with the middle of the name" do
    visit learners_path

    card = "[data-learner='#{learners(:one).id}']"
    dot_center = page.evaluate_script("(() => { const b = document.querySelector(\"#{card} .learner-color\").getBoundingClientRect(); return b.top + b.height / 2; })()")
    name_center = page.evaluate_script("(() => { const b = document.querySelector(\"#{card} [data-learner-card-link]\").getBoundingClientRect(); return b.top + b.height / 2; })()")

    assert_in_delta name_center, dot_center, 1
  end
end
