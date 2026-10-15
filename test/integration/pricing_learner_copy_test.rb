require "test_helper"

class PricingLearnerCopyTest < ActionDispatch::IntegrationTest
  setup do
    Plan.where.not(id: [plans(:premium_monthly).id, plans(:premium_yearly).id]).update_all(hidden: true)
  end

  test "public pricing and homepage cards show the approved family features" do
    [pricing_path, root_path].each do |path|
      get path
      assert_response :success
      %w[monthly yearly].each do |frequency|
        assert_select "[data-pricing-target='plans'][data-frequency='#{frequency}']" do
          assert_select "h4", text: "Free"
          assert_select "p", text: "Everything you need to run school for the whole family. Free forever."
          assert_select "p", text: "Everything in Free, plus new tools as they ship."
          assert_select "span[aria-hidden='true']", text: "*", count: 2
          cards = css_select("h4").map(&:parent)
          free_card = cards.find { |card| card.at_css("h4").text == "Free" }
          premium_card = cards.find { |card| card.at_css("h4").text == "Premium" }
          assert_equal ["Unlimited learners*", "Unlimited classes", "Both parents"], features(free_card)
          assert_equal ["Everything in Free", "Unlimited learners*", "Both parents", "New Premium features as they're added"], features(premium_card)
        end
      end
      assert_no_match(/Up to \d+ learners|>2 learners</, response.body)
    end
  end

  test "signed-out pricing shows the soft footnote with the default cap" do
    get pricing_path
    assert_footnote(15)
  end

  [:company, :subscribed, :complimentary].each do |label|
    test "#{label} family sees its own cap in the pricing footnote" do
      account = accounts(label)
      account.update!(learner_limit: 20)
      sign_in account.owner
      get pricing_path
      assert_footnote(20)
    end
  end

  private

  def features(card)
    card.css(".flex.mb-2 > div").map { |node| node.text.squish }
  end

  def assert_footnote(limit)
    assert_select "p", text: "*Cove is built for families. Teaching more than #{limit}? Just let us know."
    assert_select "p a[href^='mailto:#{Jumpstart.config.support_email}']", text: "Just let us know"
    assert_no_match(/More than \d+ learners\?/, response.body)
  end
end
