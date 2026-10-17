# AIDEV-NOTE: Class forms live in modals loaded by Turbo frames, so the Referer is still the /classes page the
# parent was on. Reading it back keeps their tab, filters, search, and page after an add, edit, delete, or
# status change without threading params through every form. Only our own list path and scalar list params are honored.
module CourseListReturn
  extend ActiveSupport::Concern
  include ReferrerPath

  LIST_PARAMS = %w[status learner subject q page].freeze

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
    uri = same_origin_referrer
    return courses_path unless uri&.path == courses_path

    list_params = Rack::Utils.parse_query(uri.query.to_s).slice(*LIST_PARAMS).select { |_, value| value.is_a?(String) }
    list_params.empty? ? courses_path : courses_path(list_params)
  end
end
