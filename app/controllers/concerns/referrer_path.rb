module ReferrerPath
  extend ActiveSupport::Concern

  private

  # AIDEV-NOTE: Shared by the return-path concerns. Returns the parsed Referer only when it points at this
  # origin, so callers can match its path and build the redirect URL locally instead of trusting the header.
  def same_origin_referrer
    uri = URI.parse(request.referer.to_s)
    uri if uri.scheme == request.scheme && uri.host == request.host && uri.port == request.port
  rescue URI::InvalidURIError
    nil
  end
end
