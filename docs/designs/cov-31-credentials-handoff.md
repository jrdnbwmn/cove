> Ticket: COV-31
> Branch: feature/cov-31-split-credentials-per-env

# Handoff: Split credentials per environment

`config/credentials/staging.yml.enc` and `config/credentials/production.yml.enc`
now exist, scaffolded from the template with fresh `secret_key_base` /
`active_record_encryption` keys and empty Stripe/Google placeholders.
`config/environments/staging.rb` now resolves mailer and controller URLs to
`staging.covehomeschool.com` instead of the production domain. The following
steps are a manual handoff — secrets and the Render key upload can't be done
by a clone.

## Render env vars

`RAILS_MASTER_KEY` is the **only** secret to set manually on Render, on the
`cove-staging` service. It equals the contents of `config/credentials/staging.key`.

Everything else in `render.yaml` is already wired: `RAILS_ENV`, `RACK_ENV`,
`WEB_CONCURRENCY=0`, and `DATABASE_URL`. `WEB_CONCURRENCY=0` keeps Puma in
single mode so the free 512MB instance can run Rails without exhausting memory.
Do not add `SOLID_QUEUE_IN_PUMA` on free-tier staging: it starts the Solid Queue
supervisor, dispatcher, and worker alongside Puma. Stripe and Google secrets
live *inside* the credentials file itself, so they need no additional Render
env vars.

## Manual steps

1. Create a **staging-specific Google OAuth client** in Google Cloud Console
   (none exists yet). Redirect URI:
   `https://staging.covehomeschool.com/users/auth/google_oauth2/callback`.
2. `bin/rails credentials:edit --environment staging` → paste Stripe **test**
   keys and the staging Google client ID/secret.
3. Copy the contents of `config/credentials/staging.key` into Render →
   `cove-staging` service → env var `RAILS_MASTER_KEY`.
4. Production stays dormant: `production.yml.enc` was created empty. Live
   Stripe keys, a production Google client, and the production
   `RAILS_MASTER_KEY` all wait for the cutover ticket.
