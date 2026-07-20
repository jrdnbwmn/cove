class ErrorsController < ActionController::Base
  layout false

  def not_found
    respond_to do |format|
      format.json { render status: :not_found }
      format.any { render status: :not_found, formats: :html, layout: "error" }
    end
  end

  def internal_server_error
    respond_to do |format|
      format.json { render status: :internal_server_error }
      format.any { render status: :internal_server_error, formats: :html, layout: "error" }
    end
  end
end
