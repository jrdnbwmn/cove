require "application_system_test_case"

class CoursesSystemTest < ApplicationSystemTestCase
  setup do
    login_as users(:one), scope: :user
  end

  test "a paid downgrade leaves all five learner checkboxes usable for adding and editing classes" do
    family = accounts(:subscribed)
    children = 5.times.map { |i| Learner.create!(account: family, name: "Child #{i}") }
    archived = Learner.create!(account: family, name: "Archived child", archived_at: Time.current)
    family.pay_subscriptions.sole.update!(status: "unpaid")
    assert family.reload.free?
    logout(:user)
    login_as users(:subscribed), scope: :user
    visit courses_path
    click_button "Add class"
    within("dialog[open]") do
      fill_in "Name", with: "Family class"
      children.each { |child| check child.name }
      assert_no_text "Read-only"
      assert_no_field archived.name
      wait_for_turbo_navigation { click_button "Add class" }
    end
    assert_no_selector "dialog[open]"
    course = family.courses.find_by!(name: "Family class")
    assert_equal children.map(&:id).sort, course.learner_ids.sort
    find("[data-course='#{course.id}']").click
    within("dialog[open]") do
      children.each do |child|
        assert_checked_field child.name, disabled: false
        uncheck child.name
      end
      wait_for_turbo_navigation { click_button "Save" }
    end
    assert_no_selector "dialog[open]"
    assert_empty course.reload.learners
  end

  test "adding the first class keeps modal headings and labels left aligned" do
    Course.where(account: accounts(:company)).destroy_all
    visit courses_path
    click_button "Add class"

    assert_selector "dialog[open] input[name='course[name]']"
    within("dialog[open]") do
      assert_equal "left", find("h2").evaluate_script("getComputedStyle(this).textAlign")
      assert_equal "left", find("label[for='course_name']").evaluate_script("getComputedStyle(this).textAlign")
    end
  end

  test "a parent can add, edit, and delete a class from the modal" do
    visit courses_path
    within("[data-page-header-actions]") { click_button "Add class" }

    within("dialog[open]") do
      fill_in "Name", with: "Algebra 1"
    end
    find("dialog[open] .ts-control").click
    assert_selector "dialog[open] > .ts-dropdown"
    find(".ts-dropdown [role='option']", text: "Math").click
    within("dialog[open]") do
      check "Maya"
      check "Theo"
      wait_for_turbo_navigation { click_button "Add class" }
    end

    assert_no_selector "dialog[open]"
    assert_text "Class added."
    assert_selector ".course-name", text: "Algebra 1"

    course = Course.order(:id).last
    assert_equal "Math", course.subject
    find("[data-course='#{course.id}']").click
    within("dialog[open]") do
      fill_in "Name", with: "Geometry"
      wait_for_turbo_navigation { click_button "Save" }
    end
    assert_text "Saved."

    find("[data-course='#{course.id}']").click
    within("dialog[open]") { click_link "Delete class" }
    within("dialog[open]") do
      assert_text "Delete Geometry?"
      wait_for_turbo_navigation { click_button "Delete Geometry" }
    end
    assert_no_selector "dialog[open]"
    assert_text "Class deleted."
    assert_no_selector ".course-name", text: "Geometry"
  end

  test "a blank class name keeps the modal and entered values open" do
    visit courses_path
    within("[data-page-header-actions]") { click_button "Add class" }

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
      wait_for_turbo_navigation { click_button "Delete Nature study" }
    end

    assert_text "Class deleted."
    assert_no_selector ".course-name", text: "Nature study"
  end

  test "cancelling a delete opened from a class menu just closes the modal" do
    visit courses_path

    open_actions_menu("Nature study")
    click_button "Delete"

    within("dialog[open]") do
      assert_text "Delete Nature study?"
      click_button "Cancel"
    end

    assert_no_selector "dialog[open]"
    assert_selector ".course-name", text: "Nature study"
  end

  test "Delete then Cancel preserves all unsaved class details through repeated confirmations" do
    visit courses_path
    open_actions_menu("Science Lab")
    click_button "Edit"
    within("dialog[open]") do
      fill_in "Name", with: "Unsaved science"
      find("select[name='course[subject]'] + .ts-wrapper .ts-control").click
      find("select[name='course[subject]'] + .ts-wrapper .ts-control input").set("Custom studies")
      find(".ts-dropdown .create").click
      assert_selector "select[name='course[subject]'] + .ts-wrapper .item", text: "Custom studies"
      uncheck "Maya"
      choose_status "Completed"
      2.times do
        click_link "Delete class"
        assert_text "Delete Science Lab?"
        click_link "Cancel"
        assert_field "Name", with: "Unsaved science"
        assert_selector "select[name='course[subject]'] + .ts-wrapper .item", text: "Custom studies"
        assert_unchecked_field "Maya"
        assert_checked_field "Theo"
        assert_selector "#course_status + .ts-wrapper .item", text: "Completed"
      end
      click_button "Cancel"
      assert_text "Discard your changes?"
      click_button "Discard"
    end
    assert_no_selector "dialog[open]"
    assert_equal "Science Lab", courses(:shared).reload.name
    assert courses(:shared).active?
  end

  test "a completed class can be edited from its menu" do
    visit courses_path(status: "completed")

    open_actions_menu("Spanish 1")
    click_button "Edit"

    within("dialog[open]") { assert_field "Name", with: "Spanish 1" }
  end

  test "choosing Completed in the edit modal and saving moves the class off the Active list" do
    visit courses_path
    find("[data-course='#{courses(:one).id}']").click

    within("dialog[open]") do
      assert_text "Status"
      choose_status "Completed"
      wait_for_turbo_navigation { click_button "Save" }
    end

    assert_no_selector "dialog[open]"
    assert_text "Algebra 1 is complete. Nice work."
    assert_no_selector ".course-name", text: "Algebra 1"
    assert courses(:one).reload.completed?
  end

  test "a name and status changed together save together and keep the current tab" do
    visit courses_path(status: "completed")
    find("[data-course='#{courses(:completed).id}']").click

    within("dialog[open]") do
      fill_in "Name", with: "Spanish 2"
      choose_status "Active"
      wait_for_turbo_navigation { click_button "Save" }
    end

    assert_no_selector "dialog[open]"
    assert_text "Spanish 2 is active again."
    assert_current_path courses_path(status: "completed")
    assert_equal "Spanish 2", courses(:completed).reload.name
    assert courses(:completed).active?
  end

  test "a completed class can only be moved back to Active from the status select" do
    visit courses_path(status: "completed")
    find("[data-course='#{courses(:completed).id}']").click

    within("dialog[open]") do
      find("#course_status + .ts-wrapper .ts-control").click
      assert_selector ".ts-dropdown [role='option']", count: 2
      assert_selector ".ts-dropdown [role='option']", text: "Active"
      assert_no_selector ".ts-dropdown [role='option']", text: "Archived"
    end
  end

  test "a parent can return a filter to all learners or all subjects from the select itself" do
    visit courses_path
    assert_selector ".course-name", text: "Piano"

    find("#course_filter_learner + .ts-wrapper .ts-control").click
    find(".ts-dropdown [role='option']", text: "Maya").click
    assert_no_selector ".course-name", text: "Piano"
    assert_includes current_url, "learner=#{learners(:one).id}"

    find("#course_filter_learner + .ts-wrapper .ts-control").click
    find(".ts-dropdown [role='option']", text: "All learners").click
    assert_selector ".course-name", text: "Piano"

    find("#course_filter_subject + .ts-wrapper .ts-control").click
    find(".ts-dropdown [role='option']", text: "Math").click
    assert_no_selector ".course-name", text: "Piano"

    find("#course_filter_subject + .ts-wrapper .ts-control").click
    find(".ts-dropdown [role='option']", text: "All subjects").click
    assert_selector ".course-name", text: "Piano"
  end

  test "adding a filtered class from the inline tile keeps the filter and confirms the add" do
    visit courses_path
    find("#course_filter_subject + .ts-wrapper .ts-control").click
    wait_for_turbo_navigation { find(".ts-dropdown [role='option']", text: "Math").click }
    assert_no_text "Piano"

    within(inline_add_tile) { click_button "Add class" }
    within("dialog[open]") do
      fill_in "Name", with: "French conversation"
    end
    find("dialog[open] .ts-control").click
    find("dialog[open] > .ts-dropdown [role='option']", text: "Arts", match: :first).click
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Add class" } }

    assert_no_selector "dialog[open]"
    assert_text "Class added."
    assert_includes current_url, "subject=Math"
    assert_no_selector ".course-name", text: "French conversation"

    click_link "Completed"
    assert_no_selector ".grid button", text: "Add class"
    click_link "Archived"
    assert_no_selector ".grid button", text: "Add class"
  end

  test "the discard prompt on the add class modal shows no Add class heading" do
    visit courses_path
    within("[data-page-header-actions]") { click_button "Add class" }

    within("dialog[open]") do
      assert_selector "h2", text: "Add class"
      fill_in "Name", with: "Algebra 1"
      click_button "Cancel"

      assert_text "Discard your changes?"
      assert_no_selector "h2", text: "Add class"
      click_button "Keep editing"
      assert_selector "h2", text: "Add class"
      assert_field "Name", with: "Algebra 1"
    end
  end

  test "the cross, an outside click, and Escape on the discard prompt keep editing" do
    visit courses_path
    within("[data-page-header-actions]") { click_button "Add class" }

    [-> { find("dialog[open] button", text: "Close").click },
      -> { page.driver.browser.action.move_to_location(5, 5).click.perform },
      -> { find("dialog[open]").send_keys(:escape) }].each do |dismiss|
      within("dialog[open]") do
        fill_in "Name", with: "Algebra 1"
        click_button "Cancel"
        assert_text "Discard your changes?"
      end

      dismiss.call

      within("dialog[open]") do
        assert_no_text "Discard your changes?"
        assert_field "Name", with: "Algebra 1"
      end
    end
    assert_selector "dialog[open]"
  end

  test "discarding changes closes the modal without the form flashing back" do
    visit courses_path
    find("[data-course='#{courses(:one).id}']").click

    within("dialog[open]") do
      fill_in "Name", with: "Algebra 2"
      page.execute_script(<<~JS)
        const dialog = document.querySelector("dialog[open]");
        const content = dialog.querySelector("[data-ui-modal-content]");
        window.formFlashed = false;
        new MutationObserver(() => {
          if (dialog.open && !content.classList.contains("hidden")) window.formFlashed = true;
        }).observe(content, {attributes: true, attributeFilter: ["class"]});
      JS
      click_button "Cancel"
      assert_text "Discard your changes?"
      click_button "Discard"
    end

    assert_no_selector "dialog[open]"
    assert_equal false, page.evaluate_script("window.formFlashed")
    assert_equal "Algebra 1", courses(:one).reload.name
  end

  test "a filter select keeps its height when All subjects is selected and open" do
    visit courses_path
    control = "#course_filter_subject + .ts-wrapper .ts-control"
    height = "document.querySelector('#{control}').getBoundingClientRect().height"
    closed_height = page.evaluate_script(height)

    find(control).click
    assert_selector ".ts-dropdown [role='option']", text: "All subjects"
    assert_equal closed_height, page.evaluate_script(height)
  end

  test "learner names sit at the bottom of every card in a row even when another title wraps" do
    long = Course.create!(account: accounts(:company), name: "LA 4th grade - The Good and the Beautiful, Part Two of Three", subject: "Language Arts")
    Enrollment.create!(course: long, learner: learners(:one))
    Enrollment.create!(course: courses(:two), learner: learners(:two))
    visit courses_path

    bottom = ->(course) { page.evaluate_script("document.querySelector(\"[data-course='#{course.id}'] .course-learners\").getBoundingClientRect().bottom") }
    card_bottom = ->(course) { page.evaluate_script("document.querySelector(\"[data-course='#{course.id}'] .course-learners\").closest('[data-course]').getBoundingClientRect().bottom") }

    [long, courses(:two)].each do |course|
      assert_in_delta card_bottom.call(course) - 24, bottom.call(course), 2, "#{course.name} learners should sit at the card's bottom padding"
    end
    assert_in_delta bottom.call(long), bottom.call(courses(:two)), 2
  end

  private

  def open_actions_menu(name)
    find("button[aria-label='Actions for #{name}']").click
    assert_selector "[role='menuitem']"
  end

  def inline_add_tile
    ".grid > [data-ui-modal-turbo-frame-src-value='#{new_course_path}'].h-full:last-child"
  end

  # The status select is a TomSelect, so pick the option from its dropdown.
  def choose_status(label)
    find("#course_status + .ts-wrapper .ts-control").click
    find(".ts-dropdown [role='option']", text: label).click
  end
end
