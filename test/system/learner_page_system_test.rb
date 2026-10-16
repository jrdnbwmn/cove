require "application_system_test_case"

class LearnerPageSystemTest < ApplicationSystemTestCase
  setup do
    @maya = learners(:one)
    login_as users(:one), scope: :user
  end

  test "editing saving archiving and restoring keep the learner page and retained class links" do
    original_links = @maya.enrollments.pluck(:id)
    visit learner_path(@maya)
    click_button "Edit"
    within("dialog[open]") do
      fill_in "Name", with: "Theo"
      click_button "Save"
      assert_text "You already have a learner named Theo."
      fill_in "Name", with: "Maya R"
      wait_for_turbo_navigation { click_button "Save" }
    end
    assert_current_path learner_path(@maya)
    assert_selector "h1", text: "Maya R"
    assert_no_selector "dialog[open]"
    click_button "Edit"
    within("dialog[open]") { wait_for_turbo_navigation { click_button "Archive" } }
    assert_current_path learner_path(@maya)
    assert_text "Maya R is archived. Maya R's records are kept."
    assert_no_button "Edit"
    assert_no_selector "[data-current-classes]"
    wait_for_turbo_navigation { click_button "Restore" }
    assert_current_path learner_path(@maya)
    assert_selector "[data-current-classes]"
    assert_equal original_links, @maya.enrollments.pluck(:id)
  end

  test "cancel asks before discarding and switcher and Classes links navigate" do
    visit learner_path(@maya)
    click_button "Edit"
    within("dialog[open]") do
      fill_in "Name", with: "Unsaved"
      click_button "Cancel"
      assert_text "Discard your changes?"
      click_button "Keep editing"
      assert_field "Name", with: "Unsaved"
      click_button "Cancel"
      click_button "Discard"
    end
    assert_no_selector "dialog[open]"
    assert_equal "Maya", @maya.reload.name
    find("button[aria-label='Switch learner']").click
    click_link "Theo", exact: true
    assert_current_path learner_path(learners(:two))
    click_link "See all in Classes"
    assert_current_path courses_path(learner: learners(:two).id)
  end

  test "a stale restore button reports capacity refusal on the learner page" do
    archived = learners(:archived)
    visit learner_path(archived)
    family = accounts(:company)
    (family.learners.active.count...15).each { |i| family.learners.create!(name: "Extra #{i}") }
    wait_for_turbo_navigation { click_button "Restore" }
    assert_current_path learner_path(archived)
    assert_text "To add more than 15 learners"
    assert_text "To restore a learner, archive one first"
    assert_no_button "Restore"
    assert archived.reload.archived?
  end

  test "phone long names wrap with accessible switcher Edit and stacked class rows" do
    @maya.update!(name: "A very long learner name that wraps across lines")
    course = accounts(:company).courses.create!(name: "A class with a long name for wrapping", subject: "Language Arts")
    course.enrollments.create!(learner: @maya)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit learner_path(@maya)
    assert_equal 390, page.evaluate_script("innerWidth")
    assert_selector "h1", text: @maya.name
    assert_no_overflow
    row = find("[data-current-class-row]", text: course.name)
    assert_equal "column", row.evaluate_script("getComputedStyle(this).flexDirection")
    switcher = find("button[aria-label='Switch learner']")
    switcher.send_keys(:enter)
    assert_selector "[role='menuitem']", text: "Theo"
    page.send_keys(:escape)
    click_button "Edit"
    assert_selector "dialog[open]"
    assert_no_overflow
    within("dialog[open]") { click_button "Cancel" }
    assert_no_selector "dialog[open]"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "phone long unbroken learner names remain visible beside controls and in confirmations" do
    @maya.update!(name: "A" * 50)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit learner_path(@maya)
    assert_text_fits("h1")
    click_button "Edit"
    assert_selector "dialog[open] h2"
    assert_heading_clear_of_close
    within("dialog[open]") { click_link "Delete" }
    assert_selector "dialog[open] h2", text: "Delete #{@maya.name}?"
    assert_heading_clear_of_close
    assert_text_fits("dialog[open] button[type='submit'] .when-enabled")
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def assert_text_fits(selector)
    assert page.evaluate_script(<<~JS, selector), "Text is clipped: #{selector}"
      (() => {
        const element = document.querySelector(arguments[0]);
        const range = document.createRange();
        range.selectNodeContents(element);
        return Array.from(range.getClientRects()).every(rect => rect.left >= 0 && rect.right <= innerWidth);
      })()
    JS
  end

  def assert_heading_clear_of_close
    assert page.evaluate_script(<<~JS), "Heading overlaps the close button"
      (() => {
        const dialog = document.querySelector('dialog[open]');
        const close = dialog.querySelector('button[data-action="ui-modal#close:prevent"]').getBoundingClientRect();
        const range = document.createRange();
        range.selectNodeContents(dialog.querySelector('h2'));
        return Array.from(range.getClientRects()).every(rect => rect.right <= innerWidth &&
          !(rect.right > close.left && rect.left < close.right && rect.top < close.bottom && rect.bottom > close.top));
      })()
    JS
  end

  def assert_no_overflow
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end
end
