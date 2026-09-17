class Api::V1::MeController < Api::BaseController
  def show
    render partial: "users/user", locals: {user: current_user}
  end

  def destroy
    if current_user.must_transfer_family_before_deletion?
      render json: {error: "Transfer family ownership before deleting your login"}, status: :unprocessable_content
    else
      current_user.destroy!
      render json: {}
    end
  end
end
