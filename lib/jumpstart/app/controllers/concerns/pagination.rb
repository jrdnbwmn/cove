module Pagination
  extend ActiveSupport::Concern

  included do
    include Pagy::Method

    rescue_from Pagy::OptionError do
      redirect_to action: action_name, params: request.query_parameters.merge(page: 1)
    end
  end
end
