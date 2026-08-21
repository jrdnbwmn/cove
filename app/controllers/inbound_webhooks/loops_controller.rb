module InboundWebhooks
  class LoopsController < ApplicationController
    # AIDEV-NOTE: This endpoint is not registered with Loops. Registration is
    # manual and dashboard-only (Settings -> Webhooks) and there is one endpoint
    # per Loops account, so it points at production only. It was never done
    # because no live production service existed to point at. Until it is, Loops
    # emits nothing here: every unsubscribe, hard bounce, and spam report is
    # invisible, and User marketing consent state drifts from Loops' silently
    # rather than noisily. Registration also requires loops.webhook_secret in
    # config/credentials/production.yml.enc -- LoopsWebhookSignature fails closed
    # without it, rejecting every event 401. Tracked in COV-65.
    def create
      webhook_id = request.headers["Webhook-Id"]
      timestamp = request.headers["Webhook-Timestamp"]
      signature_header = request.headers["Webhook-Signature"]

      verifier = LoopsWebhookSignature.new(secret: LoopsWebhookSignature.secret)
      return head :unauthorized unless verifier.valid?(webhook_id: webhook_id, timestamp: timestamp, payload: payload, signature_header: signature_header)

      begin
        parsed = JSON.parse(payload)
      rescue JSON::ParserError
        return head :bad_request
      end

      begin
        record = LoopsWebhookEvent.create!(
          webhook_id: webhook_id,
          event_name: parsed["eventName"],
          event_time: LoopsWebhookEvent.parse_event_time(parsed["eventTime"]),
          payload: parsed
        )
      rescue ActiveRecord::RecordNotUnique
        return head :ok
      end

      LoopsWebhookEventJob.perform_later(record.id)
      head :ok
    end
  end
end
