class ActionText::EmbedsController < ApplicationController
  before_action :authenticate_user!

  # AIDEV-NOTE: Creating embeds performs a remote oEmbed request and persists a row, so
  # require an account and cap requests before they can consume Puma workers or storage.
  rate_limit to: 20, within: 1.minute, only: :create, by: -> { current_user.id }, with: -> { head :too_many_requests }

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
