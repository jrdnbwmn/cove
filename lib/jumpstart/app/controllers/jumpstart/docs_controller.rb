module Jumpstart
  class DocsController < ::ApplicationController
    def pagination
      @pagy, _ = pagy(:offset, [nil] * 1000)
    end
  end
end
