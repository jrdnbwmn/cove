require "test_helper"

class ApiTokensTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @api_token = api_tokens(:one)
    @api_token.update!(name: "Primary Token")
    @other_api_token = api_tokens(:two)
    @other_api_token.update!(name: "Other User's Token")
  end

  test "can view own token index" do
    sign_in @user
    get api_tokens_path
    assert_response :success
    assert_select "a", text: @api_token.name
  end

  test "can create a new api token with a name" do
    sign_in @user
    assert_difference "@user.api_tokens.count", 1 do
      post api_tokens_path, params: {api_token: {name: "CI Deploy Key"}}
    end

    created_token = @user.api_tokens.find_by(name: "CI Deploy Key")
    assert created_token, "expected a token named 'CI Deploy Key' to have been created"
    assert_redirected_to api_token_path(created_token)
    assert_equal "CI Deploy Key", created_token.name
  end

  test "can view own token show page" do
    sign_in @user
    get api_token_path(@api_token)
    assert_response :success
    assert_select "h1", text: /#{Regexp.escape(@api_token.name)}/
  end

  test "can edit own token name and update persists" do
    sign_in @user
    get edit_api_token_path(@api_token)
    assert_response :success

    patch api_token_path(@api_token), params: {api_token: {name: "Renamed Token"}}
    assert_redirected_to api_token_path(@api_token)

    assert_equal "Renamed Token", @api_token.reload.name
  end

  test "can destroy own token" do
    sign_in @user
    assert_difference "@user.api_tokens.count", -1 do
      delete api_token_path(@api_token)
    end

    assert_response :see_other
    assert_redirected_to api_tokens_path
    assert_raises(ActiveRecord::RecordNotFound) { @api_token.reload }
  end

  test "cannot edit another user's token" do
    sign_in @other_user
    get api_tokens_path # establish an authenticated session before hitting a 404 route
    assert_response :success

    get edit_api_token_path(@api_token)
    assert_response :not_found

    patch api_token_path(@api_token), params: {api_token: {name: "Hijacked"}}
    assert_response :not_found

    assert_equal "Primary Token", @api_token.reload.name
  end

  test "cannot destroy another user's token" do
    sign_in @other_user
    get api_tokens_path # establish an authenticated session before hitting a 404 route
    assert_response :success

    assert_no_difference "ApiToken.count" do
      delete api_token_path(@api_token)
    end

    assert_response :not_found
    assert @api_token.reload.present?
  end
end
