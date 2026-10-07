# AIDEV-NOTE: Class forms live in modals loaded by Turbo frames, so the Referer is still the /classes page the
# parent was on. Reading it back (instead of threading a param through every form) keeps their tab and filters
# after an add, edit, delete, or status change. Only our own list path and its three list params are honored.
module CourseListReturn
  extend ActiveSupport::Concern

  LIST_PARAMS = %w[status learner subject].freeze

  private

  # AIDEV-NOTE: Scoped through the current family so another family's class is a 404.
  def set_nested_course
    @course = Current.account.courses.find(params[:course_id])
  end

  def redirect_to_course_list(succeeded, notice:)
    if succeeded
      redirect_to course_list_return_path, status: :see_other, notice: notice
    else
      redirect_to course_list_return_path, status: :see_other, alert: @course.errors.full_messages.to_sentence
    end
  end

  def course_list_return_path
    uri = URI.parse(request.referer.to_s)
    return courses_path unless uri.path == courses_path && [nil, request.host].include?(uri.host)

    list_params = Rack::Utils.parse_query(uri.query.to_s).slice(*LIST_PARAMS).select { |_, value| value.is_a?(String) }
    list_params.empty? ? courses_path : courses_path(list_params)
  rescue URI::InvalidURIError
    courses_path
  end
end
