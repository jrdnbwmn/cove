class Users::MentionsController < ApplicationController
  before_action :authenticate_user!
  layout false

  def index
    @users = searchable_users.search(params[:filter]).with_attached_avatar.limit(10)
  end

  private

  # By default, we'll only show the users in the current account.
  # You may want to use User.all instead to allow mentioning all users.
  def searchable_users
    current_account.users
  end
end
