require "uri"

class StagingEmailRecipientGuard
  class InvalidAllowlist < StandardError; end

  class BlockedRecipient < StandardError
    attr_reader :recipient

    def initialize(recipient)
      @recipient = recipient
      super("Staging email recipient is not allowlisted: #{recipient}")
    end
  end

  class << self
    def configure!(raw_allowlist)
      @allowlist = nil
      recipients = raw_allowlist.to_s.split(",").map { |recipient| recipient.strip }.reject(&:empty?)

      raise InvalidAllowlist, "Staging email recipient allowlist is required" if recipients.empty?
      unless recipients.all? { |recipient| URI::MailTo::EMAIL_REGEXP.match?(recipient) }
        raise InvalidAllowlist, "Staging email recipient allowlist contains an invalid address"
      end

      @allowlist = Set.new(recipients.map(&:downcase)).freeze
      new
    end

    def delivering_email(message)
      new.delivering_email(message)
    end

    def allowlist
      @allowlist || raise(InvalidAllowlist, "Staging email recipient allowlist is required")
    end
  end

  def delivering_email(message)
    recipients(message).each do |recipient|
      raise BlockedRecipient, recipient unless self.class.allowlist.include?(recipient.downcase)
    end

    nil
  end

  private

  def recipients(message)
    [message.to, message.cc, message.bcc].flatten.compact
  end
end
