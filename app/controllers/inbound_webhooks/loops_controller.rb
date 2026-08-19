module InboundWebhooks
  class LoopsController < ApplicationController
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
