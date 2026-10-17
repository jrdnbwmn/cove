class PlannersController < ApplicationController
  include CurrentSchoolYear

  def show
  end

  private

  # AIDEV-NOTE: Modal redirects keep their frame header; return the complete page and toast host.
  def set_layout
    (turbo_frame_request? && action_name == "show") ? nil : super
  end
end
