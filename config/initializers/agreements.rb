# Agreements allow you to track changes to your Terms of Service, Privacy, and other agreements & policies in your application.

Agreement = Data.define(:id, :title, :column, :updated, :prompt_when_updated) do
  def accepted_by?(user)
    accepted_at = user.public_send(column)
    accepted_at.present? && accepted_at >= updated
  end

  def not_accepted_by?(user)
    !accepted_by?(user)
  end

  def to_param
    id
  end

  def to_partial_path
    "agreements/#{id}"
  end
end

# AIDEV-NOTE: These entries exist so the Terms and Privacy pages can show a
# "Last updated" date. Nobody is prompted to re-accept because
# `require_accepted_latest_agreements!` only checks agreements with
# `prompt_when_updated: true`. For a future material change, bump `updated` and
# set `prompt_when_updated: true` so every user re-accepts once.
Rails.application.config.agreements = [
  Agreement.new(
    id: :terms_of_service,
    title: "Terms of Service",
    column: :accepted_terms_at,
    updated: Time.zone.parse("2026-10-01 00:00:00"),
    prompt_when_updated: false
  ),
  Agreement.new(
    id: :privacy_policy,
    title: "Privacy Policy",
    column: :accepted_privacy_at,
    updated: Time.zone.parse("2026-10-01 00:00:00"),
    prompt_when_updated: false
  )
]
