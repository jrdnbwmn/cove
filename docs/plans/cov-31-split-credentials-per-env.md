> Ticket: COV-31
> Branch: feature/cov-31-split-credentials-per-env

# Plan: Split Rails credentials per environment

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Scaffold staging + production credential files | Master | |
| 2    | 1     | 1          | Fix `staging.rb` URL options | Master | |
| 3    | 1     | 1          | Verify `.gitignore`, boot-verify staging host, write handoff note | Master | |

## Prerequisites

- Design: `docs/designs/cov-31-split-credentials-per-env.md`
- Prototype: None
- Feature branch exists: `feature/cov-31-split-credentials-per-env` ✓
- **Shell PATH:** every `bin/rails` command below must be prefixed with
  `export PATH="$HOME/.local/share/mise/shims:$PATH"` (mise shims gotcha).
  Confirm `ruby -v` reports 4.0.5 before trusting output.

## Tasks

### Task 1 [Master]: Scaffold staging + production credential files

**Skills:** none (config only)
**Reference:** existing `config/credentials/test.yml.enc` + `test.key` show the
per-env file layout Rails expects.

**In scope:**

- Run `EDITOR=true bin/rails credentials:edit --environment staging` — creates
  `config/credentials/staging.yml.enc` and `config/credentials/staging.key` from
  the template, saved unedited (fresh auto-generated `secret_key_base` +
  `active_record_encryption`, empty Stripe/Google placeholders).
- Run `EDITOR=true bin/rails credentials:edit --environment production` — same,
  creates `production.yml.enc` + `production.key`.
- Confirm both `.enc` files exist and both `.key` files are ignored (do not
  `git add` any `.key`).

**NOT in scope:**

- Populating any real secret values (Stripe keys, Google OAuth client) — that's
  the author's manual handoff.
- Touching the shared `config/credentials.yml.enc` / `config/master.key` or
  development credentials.
- Editing `test.yml.enc`.

**Build order:**

1. **Implement:** run the two `EDITOR=true` credentials:edit commands (with mise
   PATH prefix).
2. **Verify:** `git status --porcelain` — the two `.yml.enc` files appear as
   new/untracked; **no** `.key` file appears. `bin/rails credentials:show
   --environment staging` opens (AC #1) and `--environment production` opens
   (AC #2).

### Task 2 [Master]: Fix staging.rb URL options

**Skills:** none
**Reference:** `config/environments/staging.rb:61` (current `default_url_options`).

**In scope:**

- In `config/environments/staging.rb`, replace line 61
  `config.action_mailer.default_url_options = {host: Jumpstart.config.domain}`
  with `{host: "staging.covehomeschool.com"}`.
- Add
  `config.action_controller.default_url_options = {host: "staging.covehomeschool.com"}`.
- Add a one-line comment near the commented `asset_host` (line 21–22) noting
  assets are served same-origin — no separate CDN/asset host for staging. Leave
  `asset_host` unset.

**NOT in scope:**

- Any email-provider / SMTP configuration (deferred — `email_provider` is `""`).
- Touching `production.rb` or `Jumpstart.config.domain` itself.

**Build order:**

1. **Implement:** edit `config/environments/staging.rb` as above.
2. **Verify:** deferred to Task 3's boot check.

### Task 3 [Master]: Verify .gitignore, boot-verify staging host, write handoff note

**Skills:** none
**Reference:** `.gitignore` lines under "# Credentials & secrets"
(`/config/master.key`, `/config/credentials/*.key`).

**In scope:**

- Confirm `.gitignore` already covers `/config/master.key` and
  `/config/credentials/*.key` (it does — no edit expected). Verify via
  `git status` that no `.key` is stageable (AC #4).
- Boot-verify the staging host resolves (AC #5):
  `RAILS_MASTER_KEY=$(cat config/credentials/staging.key) RAILS_ENV=staging PATH="$HOME/.local/share/mise/shims:$PATH" bin/rails runner "puts Rails.application.config.action_mailer.default_url_options[:host]"`
  → expects `staging.covehomeschool.com`.
- Write the handoff note at `docs/designs/cov-31-credentials-handoff.md` per the
  design's "Handoff note contents": lists `RAILS_MASTER_KEY` as the only
  manually-set Render secret (= contents of `config/credentials/staging.key`),
  notes Stripe/Google secrets live inside credentials (no extra Render vars), and
  lists the author's manual steps (staging Google OAuth client, paste Stripe test
  keys, copy staging.key to Render `cove-staging`, production stays dormant).
  **No secret values** in the note (AC #6).
- **Run review-changes-mini** covering Tasks 1–3.

**NOT in scope:**

- Editing `.gitignore` (verification only).
- Performing any author handoff step (creating Google client, pasting real keys,
  pushing to Render).

**Build order:**

1. **Verify:** `git status` shows no `.key`; run the boot-verify runner command
   and confirm output is `staging.covehomeschool.com`.
2. **Implement:** write `docs/designs/cov-31-credentials-handoff.md`.
3. **Review:** run review-changes-mini on the full checkpoint (Tasks 1–3).

## Task Dependencies

- Task 3's boot-verify depends on Task 1 (needs `staging.key`) and Task 2 (needs
  the host fix).
- Tasks run sequentially: 1 → 2 → 3. No parallelism (all touch shared config;
  small change).

## Notes

- **No Minitest unit test** — pragmatic exception to test-first for pure config.
  There's no app-code behavior to unit-test; verification is the staging boot
  check (Task 3).
- Fresh `secret_key_base` / AR-encryption keys for production are safe
  pre-cutover (no encrypted data yet).
- Deferred (out of this ticket): production go-live cutover, staging email
  delivery, migrating development off the shared credentials file.
