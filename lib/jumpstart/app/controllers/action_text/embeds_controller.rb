class ActionText::EmbedsController < ApplicationController
  def create
    @embed = ActionText::Embed.from_url(params[:id])
    if @embed
      render json: {
        sgid: @embed.attachable_sgid,
        content: render_to_string(partial: @embed.to_partial_path, object: @embed, as: :embed, formats: [:html])
      }
    else
      head :not_found
    end
  end
end
