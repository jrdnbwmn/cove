require "test_helper"

class LearnerPageActionsTest < ActionDispatch::IntegrationTest
  setup do
    @maya = learners(:one)
    @family = accounts(:company)
  end

  [:one, :two].each do |parent|
    test "#{parent} saves archives and restores on the learner page" do
      sign_in users(parent)
      headers = {"HTTP_REFERER" => "http://www.example.com#{learner_path(@maya)}"}
      patch learner_path(@maya), params: {learner: {name: "Theo"}}, headers: headers
      assert_response :unprocessable_content
      patch learner_path(@maya), params: {learner: {name: "Maya R"}}, headers: headers
      assert_redirected_to learner_path(@maya)
      post learner_archive_path(@maya), headers: headers
      assert_redirected_to learner_path(@maya)
      assert @maya.reload.archived?
      get edit_learner_path(@maya), headers: headers
      assert_redirected_to learner_path(@maya)
      patch learner_path(@maya), params: {learner: {name: "No"}}, headers: headers
      assert_redirected_to learner_path(@maya)
      delete learner_archive_path(@maya), headers: headers
      assert_redirected_to learner_path(@maya)
      assert_not @maya.reload.archived?
    end
  end

  test "a refused Restore stays on its learner page" do
    sign_in users(:one)
    archived = learners(:archived)
    13.times { |i| @family.learners.create!(name: "Extra #{i}") }
    delete learner_archive_path(archived), headers: {"HTTP_REFERER" => "http://www.example.com#{learner_path(archived)}"}
    assert_redirected_to learner_path(archived)
    assert archived.reload.archived?
    assert_match(/To add more than 15 learners/, flash[:alert])
  end

  test "only the exact same-origin learner page is a return destination" do
    sign_in users(:one)
    [nil, "http://www.example.com/learners", "http://www.example.com#{learner_path(learners(:two))}", "https://evil.example#{learner_path(@maya)}", "http://www.example.com:9999#{learner_path(@maya)}", "https://www.example.com#{learner_path(@maya)}", "//evil.example#{learner_path(@maya)}", "/learners/#{@maya.id}", "%%%"].each do |referer|
      headers = referer ? {"HTTP_REFERER" => referer} : {}
      patch learner_path(@maya), params: {learner: {grade_level: "4th grade"}}, headers: headers
      assert_redirected_to learners_path
      post learner_archive_path(@maya), headers: headers
      assert_redirected_to learners_path
      delete learner_archive_path(@maya), headers: headers
      assert_redirected_to learners_path
    end
  end

  test "Add and Delete always return to Learners even from a learner page" do
    sign_in users(:one)
    headers = {"HTTP_REFERER" => "http://www.example.com#{learner_path(@maya)}"}
    post learners_path, params: {learner: {name: "New"}}, headers: headers
    assert_redirected_to learners_path
    delete learner_path(@maya), headers: headers
    assert_redirected_to learners_path
  end
end
