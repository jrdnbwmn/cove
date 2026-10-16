require "test_helper"

class LearnerPageTest < ActionDispatch::IntegrationTest
  setup do
    @maya = learners(:one)
    @maya.enrollments.destroy_all
    @family = accounts(:company)
    sign_in users(:one)
  end

  test "the title switcher lists only other active family learners in creation order" do
    learners(:two).update_columns(created_at: 2.days.ago)
    later = @family.learners.create!(name: "Later")
    outsider = accounts(:one).learners.create!(name: "Outsider")
    get learner_path(@maya)
    assert_select "[data-page-header-title-suffix]" do
      assert_equal [learner_path(learners(:two)), learner_path(later)], css_select("[data-page-header-title-suffix] a").map { |a| a["href"] }
      assert_select "a[href='#{learner_path(@maya)}']", count: 0
      assert_select "a[href='#{learner_path(learners(:archived))}']", count: 0
      assert_select "a[href='#{learner_path(outsider)}']", count: 0
    end
    assert_select "[data-page-header-actions] button", text: "Edit"
    assert_select "[data-page-header-actions] [data-ui-modal-turbo-frame-src-value='#{edit_learner_path(@maya)}']"
    assert_select "[data-page-header-actions] button.border", text: "Edit"
    assert_select "[data-page-header-actions] button[aria-label='More actions']", count: 0
  end

  test "a learner with no destinations or grade has no switcher or grade line" do
    learners(:two).archive!
    @maya.update!(grade_level: nil)
    get learner_path(@maya)
    assert_select "[data-page-header-title-suffix]", count: 0
    assert_select "h1 + p", count: 0
  end

  test "archived learners are view only with an active switcher and Restore" do
    get learner_path(learners(:archived))
    assert_select "h3", text: "Iris is archived. Iris's records are kept."
    assert_select "button", text: "Edit", count: 0
    assert_select "form[action='#{learner_archive_path(learners(:archived))}'] button", text: /Restore/
    assert_select "[data-page-header-title-suffix] a[href='#{learner_path(@maya)}']"
    assert_select "[data-current-classes]", count: 0
  end

  test "archived learner Restore is unavailable at capacity with the support path" do
    @family.update!(learner_limit: 15)
    13.times { |i| @family.learners.create!(name: "Extra #{i}") }
    get learner_path(learners(:archived))
    assert_select "button", text: /Restore/, count: 0
    assert_select "p", text: /To restore a learner, archive one first/
    assert_select "a[href^='mailto:']", text: "send us a note"
  end
  test "current classes include every active linked class in subject and name order" do
    classes = [["Zebra", "Science"], ["Bravo", "Math"], ["Alpha", "Math"], ["No subject", nil]].map do |name, subject|
      @family.courses.create!(name: name, subject: subject).tap { |course| course.enrollments.create!(learner: @maya) }
    end
    13.times do |i|
      course = @family.courses.create!(name: "Extra #{i}", subject: "Arts")
      course.enrollments.create!(learner: @maya)
      classes << course
    end
    %w[completed archived].each do |status|
      course = @family.courses.create!(:name => "Hidden #{status}", "#{status}_at" => Time.current)
      course.enrollments.create!(learner: @maya)
    end
    @family.courses.create!(name: "Not linked")
    get learner_path(@maya)
    assert_equal @maya.courses.active.ordered.pluck(:name), css_select("[data-current-class-name]").map(&:text)
    assert_select "[data-current-classes] > .border #current-classes-title.font-sans", text: "Current classes and activities"
    assert_select "[data-current-classes] > .border [data-current-class-row]", count: 17
    assert_select "[data-current-class-row] a, [data-current-class-row] button", count: 0
    assert_select "[data-current-class-subject]", count: 16
    assert_select "[data-current-classes] a[href='#{courses_path(learner: @maya.id)}']", text: "See all in Classes"
    assert_select "[data-current-classes] input, [data-current-classes] button", count: 0
    @maya.archive!
    get learner_path(@maya)
    assert_select "[data-current-classes]", count: 0
  end

  test "no current classes explains what belongs here and links to Classes without Add" do
    get learner_path(@maya)
    assert_select "[data-current-classes] > .border h2.font-sans", text: "Current classes and activities"
    assert_select "h3", text: "No classes yet."
    assert_select "p", text: "Classes Maya takes will appear here."
    assert_select "[data-current-classes] a[href='#{courses_path(learner: @maya.id)}']", text: "See all in Classes"
    assert_select "button, a", text: /Add class/, count: 0
    assert_no_match(/Recent work|Coming up|This year|Paperwork/, response.body)
  end
end
