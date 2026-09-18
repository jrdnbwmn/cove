module Madmin
  class PlansController < Madmin::ResourceController
    # AIDEV-NOTE: Plan's before_destroy guard blocks deleting plans with subscribers;
    # surface its error instead of silently redirecting to the index.
    def destroy
      if @record.destroy
        redirect_to resource.index_path
      else
        redirect_to resource.show_path(@record), alert: @record.errors.full_messages.to_sentence
      end
    end

    private

    # Add support for features array
    def resource_params
      params.require(resource.param_key)
        .permit(*resource.permitted_params, features: [])
        .with_defaults(features: [])
        .transform_values { |v| change_polymorphic(v) }
    end
  end
end
