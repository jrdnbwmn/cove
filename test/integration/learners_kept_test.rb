require "test_helper"

class LearnersKeptTest < ActionDispatch::IntegrationTest
  test "guests are sent to sign in and another family's id is rejected" do
    get edit_learners_kept_path
    assert_redirected_to new_user_session_path

    sign_in users(:downgraded)
    patch learners_kept_path, params: {learner_ids: [learners(:kept).id, learners(:one).id]}
    assert_response :unprocessable_content
    assert_not learners(:one).reload.kept_on_free?
  end

  test "a downgraded parent can open the picker and save two active learners" do
    sign_in users(:downgraded)

    get edit_learners_kept_path
    assert_response :success
    assert_select "turbo-frame#modal-lazy-content"
    assert_select "input[name='learner_ids[]']", count: 5

    patch learners_kept_path, params: {learner_ids: [learners(:read_only).id, learners(:read_only_two).id]}

    assert_redirected_to learners_path
    assert_predicate learners(:read_only).reload, :kept_on_free?
    assert_predicate learners(:read_only_two).reload, :kept_on_free?
  end

  test "the picker's buttons stack with Save on top on phones" do
    sign_in users(:downgraded)

    get edit_learners_kept_path

    assert_select "form div.flex-col-reverse.sm\\:flex-row button", count: 2
  end

  test "malformed learner ids show the picker error instead of failing" do
    sign_in users(:downgraded)

    patch learners_kept_path, params: {learner_ids: {"0" => learners(:kept).id}}
    assert_response :unprocessable_content
    assert_match "Choose 2 learners to keep editable.", response.body

    patch learners_kept_path, params: {learner_ids: "not-an-array"}
    assert_response :unprocessable_content
  end

  test "a rejected pick keeps the boxes the parent ticked" do
    sign_in users(:downgraded)

    patch learners_kept_path, params: {learner_ids: [learners(:read_only).id]}

    assert_response :unprocessable_content
    assert_select "input[name='learner_ids[]'][value='#{learners(:read_only).id}'][checked]"
    assert_select "input[name='learner_ids[]'][value='#{learners(:kept).id}'][checked]", count: 0
  end

  test "the picker rejects invalid and stale selections and redirects when the limit no longer applies" do
    sign_in users(:downgraded)

    patch learners_kept_path, params: {learner_ids: [learners(:kept).id]}
    assert_response :unprocessable_content
    assert_match "Choose 2 learners to keep editable.", response.body

    learners(:read_only).archive!
    learners(:read_only_two).archive!
    learners(:read_only_three).archive!
    get edit_learners_kept_path
    assert_redirected_to learners_path
  end
end
