require "test_helper"

class LearnersIndexTest < ActionDispatch::IntegrationTest
  test "a parent sees active learners as cards in creation order without archived ones" do
    # Fixtures share one timestamp; set explicit ones so creation order is unambiguous.
    learners(:one).update_columns(created_at: 2.days.ago)
    learners(:two).update_columns(created_at: 1.day.ago)
    sign_in users(:one)

    get learners_path

    assert_response :success
    names = css_select(".grid p.font-medium")
      .reject { |node| node.ancestors.any? { |ancestor| ancestor["data-ui-modal-unsaved-changes-target"] == "discardPrompt" } }
      .map { |node| node.text.strip }
    assert_equal %w[Maya Theo], names
    assert_no_match "Iris", response.body
  end

  test "an active learner's menu offers Edit, which opens that learner's edit modal" do
    sign_in users(:one)

    get learners_path

    form_id = ActionView::RecordIdentifier.dom_id(learners(:one), :edit)
    assert_select "button[form='#{form_id}']", text: /Edit/
    assert_select "form##{form_id}[data-action='submit->ui-modal#open:prevent']"
  end

  test "an archived learner's menu has no Edit" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path(archived: 1)

    assert_select "button", text: /Edit/, count: 0
  end

  test "the Delete menu item is red with a red-tinted hover background" do
    sign_in users(:one)

    get learners_path

    assert_select "button.text-red-600.hover\\:bg-red-50", text: /Delete/
  end

  test "grade level shows only for learners who have one" do
    sign_in users(:one)

    get learners_path

    assert_select ".grid p.text-muted-foreground", count: 1, text: "3rd grade"
  end

  test "each learner card has a decorative color dot using its color token" do
    sign_in users(:one)

    get learners_path

    assert_select ".grid span.learner-color[data-learner-color='sage'][aria-hidden='true']", count: 1
    assert_select ".grid span.learner-color[data-learner-color='sea'][aria-hidden='true']", count: 1
    assert_select ".grid span.learner-color[style]", count: 0
  end

  test "a parent can open the add learner modal from the header" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path

    assert_select "[data-page-header-actions] [data-ui-modal-turbo-frame-src-value='#{new_learner_path}']", count: 1
    assert_select "h2", text: "Add learner"
    assert_select "button[data-action='click->ui-modal#open:prevent']", text: /Add learner/
  end

  test "the Active learner grid ends with the add tile while the header trigger remains unchanged" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path

    assert_select "[data-page-header-actions] [data-ui-modal-turbo-frame-src-value='#{new_learner_path}']:not(.h-full)", count: 1
    assert_select ".grid > [data-ui-modal-turbo-frame-src-value='#{new_learner_path}'].h-full:last-child" do
      assert_select "button[data-action='click->ui-modal#open:prevent']", text: "Add learner"
    end
  end

  test "the learner tile is absent from Archived and empty views" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path(archived: 1)

    assert_select ".grid > [data-ui-modal-turbo-frame-src-value='#{new_learner_path}'].h-full", count: 0

    learners(:one).archive!
    get learners_path

    assert_select ".grid > [data-ui-modal-turbo-frame-src-value='#{new_learner_path}'].h-full", count: 0
  end

  [:company, :subscribed, :complimentary].each do |label|
    test "#{label} family sees both soft modal triggers at capacity" do
      account = accounts(label)
      (account.learners.active.count...15).each { |i| Learner.create!(account: account, name: "Learner #{i}") }
      sign_in account.owner
      get learners_path
      assert_response :success
      assert_select "[data-page-header-actions] dialog h2", text: "Adding more than 15 learners?"
      assert_select ".grid > [data-controller~='ui-modal'].h-full:last-child dialog h2", text: "Adding more than 15 learners?"
      assert_select "dialog" do
        assert_select "p", text: "Cove is built for families, so we check in at 15. Send us a quick note and we'll raise it for you."
        assert_select "button", text: "Close"
        assert_select "a[href^='mailto:']", text: "Email us"
        assert_select "a[href='#{pricing_path}']", count: 0
      end
      css_select("dialog").each { |dialog| assert_no_match(/Free|Premium|Upgrade/, dialog.text) }
      assert_select "[data-ui-modal-turbo-frame-src-value='#{new_learner_path}']", count: 0
    end

    test "#{label} family sees both Add form triggers below capacity" do
      account = accounts(label)
      Learner.create!(account: account, name: "First") if account.learners.active.none?
      sign_in account.owner
      get learners_path
      assert_select "[data-page-header-actions] [data-ui-modal-turbo-frame-src-value='#{new_learner_path}']", count: 1
      assert_select ".grid > [data-ui-modal-turbo-frame-src-value='#{new_learner_path}'].h-full", count: 1
    end
  end

  test "a Free family with a raised cap uses twenty in the modal" do
    account = accounts(:company)
    account.update!(learner_limit: 20)
    (account.learners.active.count...20).each { |i| Learner.create!(account: account, name: "Learner #{i}") }
    sign_in users(:one)
    get learners_path
    assert_select "dialog h2", text: "Adding more than 20 learners?", count: 2
    assert_select "dialog p", text: "Cove is built for families, so we check in at 20. Send us a quick note and we'll raise it for you.", count: 2
    account.learners.active.last.archive!
    get learners_path
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_learner_path}']", count: 2
  end

  test "a family under its limit sees the Add trigger and no prompt" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path

    assert_select "[data-page-header-actions] [data-ui-modal-turbo-frame-src-value='#{new_learner_path}']", count: 1
    assert_select "a[href='#{pricing_path}']", count: 0
    assert_no_match "Free includes", response.body
  end

  test "every active learner in a downgraded family has Edit Archive and Delete without badges" do
    sign_in users(:downgraded)
    get learners_path
    assert_no_match(/Read-only|Choose learners|stay editable/, response.body)
    accounts(:downgraded).learners.active.each do |learner|
      assert_select "[data-learner='#{learner.id}']" do
        assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_learner_path(learner)}']", count: 1
        assert_select "[role='menuitem']", count: 3
      end
    end
  end

  [:company, :subscribed].each do |label|
    test "#{label} family at capacity sees soft restore guidance" do
      account = accounts(label)
      (account.learners.active.count...15).each { |i| Learner.create!(account: account, name: "Learner #{i}") }
      archived = Learner.create!(account: account, name: "Old", archived_at: 1.day.ago)
      sign_in account.owner
      get learners_path(archived: 1)
      assert_select "p.text-muted-foreground", text: "To restore a learner, archive one first or send us a note and we'll make room."
      assert_select "a[href^='mailto:']", text: "send us a note"
      assert_select "form[action='#{learner_archive_path(archived)}']", count: 0
    end
  end

  test "a family under its limit can restore archived learners with no note" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path(archived: 1)

    assert_select "form[action='#{learner_archive_path(learners(:two))}']", count: 1
    assert_select "button", text: /Restore/
    assert_no_match "To restore a learner", response.body
  end

  test "a family with archived learners sees an Active/Archived control with counts" do
    sign_in users(:one)

    get learners_path

    assert_select "nav[aria-label='Filter learners']" do
      assert_select "a[href='#{learners_path}'][aria-current='page']", text: /Active/
      assert_select "a[href='#{learners_path(archived: 1)}']:not([aria-current])", text: /Archived/
    end
    assert_select "nav[aria-label='Filter learners'] a", text: /Active\s*2/
    assert_select "nav[aria-label='Filter learners'] a", text: /Archived\s*1/
  end

  test "a family with no archived learners does not see the control" do
    sign_in users(:subscribed)

    get learners_path

    assert_select "nav[aria-label='Filter learners']", count: 0
  end

  test "the Archived view shows only archived learners in the same grid" do
    sign_in users(:one)

    get learners_path(archived: 1)

    assert_select "nav[aria-label='Filter learners'] a[aria-current='page']", text: /Archived/
    names = css_select(".grid p.font-medium").map { |node| node.text.strip }
    assert_includes names, "Iris"
    assert_not_includes names, "Maya"
    assert_not_includes names, "Theo"
    assert_select "h2", text: "Archived", count: 0
  end

  test "a family whose learners are all archived still sees the control above the empty state" do
    learners(:one).archive!
    learners(:two).archive!
    sign_in users(:one)

    get learners_path

    assert_select "nav[aria-label='Filter learners'] a[aria-current='page']", text: /Active\s*0/
    assert_select "nav[aria-label='Filter learners'] a[href='#{learners_path(archived: 1)}']", text: /Archived\s*3/
    assert_select "h2", text: "Add your first learner"
  end

  test "an active learner's name opens their page and the card has no footer buttons" do
    sign_in users(:one)

    get learners_path

    assert_select "[data-learner='#{learners(:one).id}']" do
      assert_select "a[href='#{learner_path(learners(:one))}'][data-learner-card-link]", text: "Maya"
      assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_learner_path(learners(:one))}']", count: 1
      assert_select "button", text: "Edit", count: 1 # only the menu item, not a footer button
      assert_select "button[aria-label='Actions for Maya']", count: 1
    end
  end

  test "an active learner's actions menu offers Edit, Archive and Delete" do
    sign_in users(:one)

    get learners_path

    assert_select "[data-learner='#{learners(:one).id}']" do
      assert_select "[role='menuitem']", count: 3
      assert_select "button[role='menuitem'][type='submit'][form]", text: /Edit/
      assert_select "button[role='menuitem'][type='submit'][form]", text: /Archive/
      assert_select "button[role='menuitem']", text: /Delete/
      assert_select "form[action='#{learner_archive_path(learners(:one))}'][method='post']", count: 1
      assert_select "[data-ui-modal-turbo-frame-src-value='#{delete_learner_path(learners(:one), from: "list")}']", count: 1
    end
  end

  test "a learner's delete modal has no title of its own, so the confirmation heading is the only one" do
    sign_in users(:one)

    get learners_path

    delete_modal = "[data-ui-modal-turbo-frame-src-value='#{delete_learner_path(learners(:one), from: "list")}']"
    assert_select delete_modal, count: 1
    assert_select "#{delete_modal} h2", count: 0
  end

  test "an archived learner opens their page and its menu offers Restore and Delete" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path(archived: 1)

    assert_select "[data-learner='#{learners(:archived).id}']" do
      assert_select "a[href='#{learner_path(learners(:archived))}'][data-learner-card-link]", text: "Iris"
      assert_select "[role='menuitem']", count: 2
      assert_select "button[role='menuitem'][type='submit'][form]", text: /Restore/
      assert_select "button[role='menuitem']", text: /Delete/
    end
  end

  test "active and archived learner cards expose a stretched navigation link" do
    learners(:two).archive!
    sign_in users(:one)

    get learners_path

    assert_select "[data-learner='#{learners(:one).id}'] [data-learner-card-link]", count: 1

    get learners_path(archived: 1)

    assert_select "[data-learner='#{learners(:two).id}'] a[data-learner-card-link]", count: 1
  end

  test "each card has an edit trigger for that learner" do
    sign_in users(:one)

    get learners_path

    learners = [learners(:one), learners(:two)]
    learners.each do |learner|
      assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_learner_path(learner)}']", count: 1
      assert_select "[data-ui-modal-turbo-frame-src-value='#{edit_learner_path(learner)}'] h2", count: 0
    end

    learners.each do |learner|
      get edit_learner_path(learner)
      assert_select "turbo-frame#modal-lazy-content h2", text: "Edit #{learner.name}"
    end
  end

  test "a family with no active learners sees an empty state with an add trigger" do
    sign_in users(:noaccount)

    get learners_path

    assert_response :success
    assert_select "h2", text: "Add your first learner"
    assert_select "p", text: "Each learner gets a color so you can spot them across Cove."
    assert_select ".grid p.font-medium", count: 0
    assert_select "[data-ui-modal-turbo-frame-src-value='#{new_learner_path}']", count: 1
  end

  test "a family whose only learners are archived sees the empty state" do
    learners(:one).archive!
    learners(:two).archive!
    sign_in users(:one)

    get learners_path

    assert_select "h2", text: "Add your first learner"
  end

  test "every learner color has a token and views never hardcode hex colors" do
    css = File.read(Rails.root.join("app/assets/tailwind/application.css"))
    Learner::COLORS.each do |color|
      assert_match(/--learner-#{color}:\s*#\h{6};/, css, "missing --learner-#{color} token")
    end

    Dir[Rails.root.join("app/views/learners/**/*.erb")].each do |path|
      assert_no_match(/#\h{3,8}\b/, File.read(path), "hex value in #{path}")
    end
  end
end
