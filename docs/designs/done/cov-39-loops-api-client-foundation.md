> Ticket: COV-39
> Branch: feature/cov-39-loops-api-client-foundation
> Plan created: docs/plans/cov-39-loops-api-client-foundation.md

# Feature: Loops API client foundation and per-environment credentials

## Problem

Nothing in the app can talk to Loops — no client, no credential key, no error
mapping. COV-43, COV-44, COV-45, COV-46, and COV-50 all wait on it. This ticket
builds the foundation (auth, base URL, error mapping, idempotency, timeouts) plus
the single transactional send method, shaped so COV-50 can extend it additively.

## Approach

`LoopsClient < ApplicationClient`, per COV-37 Decision 2 — the `loops_sdk` gem was
already declined there with its source read, so **no gem approval is needed and
nothing goes in the Gemfile**. Plus a retrying mail delivery job that COV-37
assigned to this ticket.

### `app/clients/loops_client.rb`

```ruby
class LoopsClient < ApplicationClient
  BASE_URI = "https://app.loops.so/api"

  # Loops status codes ApplicationClient doesn't cover
  class BadRequest < Error; end      # 400 — transactional email not published
  class Conflict < Error; end        # 409 — idempotency key reused (and other conflicts)
  class PayloadTooLarge < Error; end # 413

  def self.client
    new(token: Rails.application.credentials.dig(:loops, :api_key))
  end

  def open_timeout = 2
  def read_timeout = 5

  def send_transactional(email:, transactional_id:, data_variables: {})
    post "/v1/transactional",
      body: { email:, transactionalId: transactional_id, addToAudience: false,
              dataVariables: data_variables },
      headers: { "Idempotency-Key" => idempotency_key(transactional_id, email, data_variables) }
    true
  rescue Conflict
    Rails.logger.info("[Loops] duplicate transactional send suppressed for #{transactional_id}")
    true
  end

  def idempotency_key(transactional_id, email, data_variables)
    Digest::SHA256.hexdigest([transactional_id, email,
      data_variables.transform_keys(&:to_s).sort.to_h.to_json].join(":"))
  end

  def handle_response(response)
    case response.code
    when "400" then raise self.class::BadRequest, response.body
    when "409" then raise self.class::Conflict, response.body
    when "413" then raise self.class::PayloadTooLarge, response.body
    else super
    end
  end
end
```

Five decisions embedded above, each with its reason:

1. **`handle_response` delegates to `super`** rather than restating the
   401/403/404/422/429/500 branches. Additive, and it cannot drift from
   `ApplicationClient#handle_response`
   (`lib/jumpstart/app/clients/application_client.rb:237-258`).
   `ApplicationClient.inherited` (line 47-59) auto-generates
   `Unauthorized`/`NotFound`/`UnprocessableContent`/`RateLimit`/`InternalError`
   subclasses for free; it does **not** generate `BadRequest`, `Conflict`, or
   `PayloadTooLarge`, so those are declared by hand. Inside the class body they
   resolve to `LoopsClient::Error` (set by `inherited` before the body runs).

2. **`addToAudience: false` is hard-coded with no keyword to override it.** With
   marketing landing from COV-48 onward, a `true` here would silently add
   password-reset recipients to a marketing audience they never consented to.
   Contacts are created deliberately and with consent in COV-51.

3. **The 409 rescue lives inside `send_transactional` only.** `handle_response`
   keeps raising `Conflict`, so COV-50's contact and campaign calls cannot
   silently swallow a real failure — Loops overloads 409 to mean "email or userId
   already exists," "campaign is not draft," and "`expectedRevisionId` is stale"
   as well as "idempotency key reused." A globally-successful 409 would report a
   stale-revision campaign update as saved when nothing was written. Honoring
   COV-37's constraint structurally beats honoring it by convention.

4. **`send_transactional` returns `true` on both paths.** AC #3 requires a 409 to
   be indistinguishable from a first send. Returning the `Response` on success and
   `nil` on the duplicate would violate that and leave a `NoMethodError` trap for a
   future caller. Nothing needs Loops' response body — it is `{"success": true}`.

5. **Timeouts: `open_timeout 2`, `read_timeout 5`.** `ApplicationClient#read_timeout`
   returns `nil` by default, inheriting Net::HTTP's. Both staging and production
   enqueue rather than deliver inline, so this is not about user-facing latency —
   it is about not pinning a job thread on a hung Loops connection.

### Idempotency key

`SHA256([transactionalId, recipient, dataVariables])`, per COV-37 — **not** the
`"#{trigger}:#{source_id}:#{recipient}"` form the ticket proposed. The two docs
disagreed; the content hash wins because:

- It is always 64 hex characters, so the 100-char Loops limit is never approached
  and there is no truncation branch to write or test.
- It is per-recipient by construction, which dissolves the `Pay.mail_to` fan-out
  problem: `config/initializers/pay.rb:8-17` returns an **array** of up to two
  recipients (account owner plus `account.billing_email`), so one webhook becomes
  two API calls. A key derived from the event id alone would make the second call
  409 — now treated as success — and the billing contact would silently never
  receive their copy.
- There is no `source_id` available at the client boundary anyway. A
  `Mail::Message` carries no event id.

Keys are stringified and sorted before hashing so a mailer that builds
`dataVariables` in a different order across retries still produces the same key.
`dataVariables` are flat (Loops caps string values at 500 chars and does not
support nesting), so a flat sort is sufficient.

**The rule this imposes on COV-43/44/45**, to be recorded as an `# AIDEV-NOTE:` on
the method: *nothing in `dataVariables` may vary between retries of the same
logical send* — no `Time.current`, no `SecureRandom`. If it varies, the key
changes and the recipient is mailed twice. This is correct rather than merely
convenient: `reset_password_instructions` carries a fresh token per request, so
repeated deliberate resets are genuinely distinct sends and are not suppressed.

### `app/jobs/loops_mail_delivery_job.rb`

```ruby
class LoopsMailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
    Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer
end
```

Wired via `config.action_mailer.delivery_job` in `config/application.rb`.

COV-37 assigned this to COV-39 ("Owned here because COV-43/44/45 all depend on
it"). It exists because **nothing retries a failed mail job today**:
`ActionMailer::Base.delivery_job` is `ActionMailer::MailDeliveryJob`, whose
superclass is `ActiveJob::Base`, **not** `ApplicationJob` — so the commented-out
`retry_on` in `app/jobs/application_job.rb:3` would never reach it even if
enabled, and ActiveJob does not retry by default. A Loops 429 or 500 currently
fails the send permanently on the first attempt, silently. At 10 req/sec per team
with billing fan-out doubling calls per webhook, 429 is a live risk.

**`Net::OpenTimeout` and `Net::ReadTimeout` are additions** not named by COV-37 or
the ticket. We are setting explicit timeouts for the first time; without these two
in the list, a timeout fails the mail job permanently — the exact failure mode
this job exists to prevent.

Two caveats, stated rather than papered over:

- With no delivery method built yet, this job's only test is that it declares
  those handlers and is wired up. No end-to-end proof until COV-43.
- Retries do not survive a restart under staging's `:async` adapter. COV-37
  already records Solid Queue as a production precondition; this does not fix it.

## Acceptance Criteria

- [ ] A successful send issues one `POST https://app.loops.so/api/v1/transactional`
      with the expected `email`, `transactionalId`, `dataVariables`, and
      `Idempotency-Key` header
- [ ] `addToAudience` is `false` on every request and cannot be overridden — proved
      by passing `data_variables: { addToAudience: true }` and asserting the
      top-level field is still `false`
- [ ] 409 returns successfully and does not raise; nothing reaches Honeybadger
- [ ] 422 raises `LoopsClient::UnprocessableContent`
- [ ] 429 raises `LoopsClient::RateLimit`
- [ ] 400 raises `LoopsClient::BadRequest`; 413 raises `LoopsClient::PayloadTooLarge`
- [ ] The idempotency key is stable across two calls with identical arguments,
      differs between two recipients of the same send, and never exceeds 100 chars
- [ ] The `Authorization: Bearer` header carries the token
- [ ] `LoopsMailDeliveryJob` declares retry handlers for `RateLimit`,
      `InternalError`, `Net::OpenTimeout`, and `Net::ReadTimeout`
- [ ] `bin/rails test` passes, output shown
- [ ] `bin/rubocop` clean
- [ ] `credentials:edit --environment staging` and `--environment production`
      round-trip with a `loops: api_key:` entry — **see Blocked below**
- [ ] No key value committed; `git status` shows no stageable `.key` file

WebMock already blocks external HTTP, so a leaked real call fails loudly.

## Prototype

None.

## Data Model

No changes. No models, migrations, screens, or routes.

## Screens / Flows

None — this is a client library with no UI. Its consumers are COV-43/44/45.

## Scope

**In:** `app/clients/loops_client.rb`, `app/jobs/loops_mail_delivery_job.rb`, the
`config.action_mailer.delivery_job` line, `test/clients/loops_client_test.rb`,
`test/jobs/loops_mail_delivery_job_test.rb`, and `loops: api_key:` in the staging
and production credentials.

**Deferred:**

- **No initializer.** The JSP api_client generator's `self.client` pattern already
  reads `Rails.application.credentials.dig(:loops, :api_key)`. A
  `config/initializers/loops.rb` would add only boot-time fail-fast on a missing
  key — which would *break* dev and test, where no key exists and none is wanted.
  The ticket asked for one; it earns nothing here.
- **No `config/loops.yml`.** COV-37 Decision 3 puts `transactionalId`s there, but
  this ticket has none to put in it — templates are authored in COV-40/41/42. It
  would ship empty. COV-43 creates it, using the `shared:` block that COV-38
  Decision 2 settled on.
- **No `attachments` parameter.** COV-37 resolved the receipt PDF as link-not-attach,
  so no caller in COV-43/44/45 will pass attachments. Three lines to add when
  something needs them.
- **No dev or test credential key.** Dev uses `:mailbin`
  (`config/environments/development.rb:80`) and test uses `:test`
  (`config/environments/test.rb:37`) — neither reaches Loops. COV-38 created only
  two keys, `cove-staging` and `cove-production`. Tests pass `token: "test"`
  explicitly, as `test/clients/application_client_test.rb` does.
- **No mailer, delivery-method, or trigger changes** — COV-43/44/45. The
  `LoopsDelivery` delivery method from COV-37 Decision 1 is not built here.
- **Staging enablement** — COV-46. **Contacts, lists, events, suppression** — COV-50.

### Blocked: the credentials ACs are a manual handoff

`config/credentials/staging.key` and `production.key` **do not exist** — not in
this workspace and not in the main checkout at `~/Documents/Repos/cove`. Only
`test.key` is present. They are gitignored (`.gitignore:48`), and
`.conductor/settings.toml` copies only `master.key` and `test.key` into workspaces.

- **Staging:** recover the key from Render → `cove-staging` service → env var
  `RAILS_MASTER_KEY`, per COV-31's handoff note. Write it to
  `config/credentials/staging.key`, then `bin/rails credentials:edit --environment
  staging` and add `loops: api_key:` with the `cove-staging` value from COV-38.
- **Production:** the key appears lost. `production.yml.enc` was created empty by
  COV-31 ("production stays dormant"), so regenerating it costs nothing — delete
  it and re-run `credentials:edit --environment production`. Production is not
  provisioned either way; `render.yaml`'s production block is commented out.

Neither the code nor the tests depend on these, so the client, job, and full test
suite ship complete regardless. This is Jordan's step, not a clone's.

## Open Questions

1. **Does `config.action_mailer.delivery_job` accept a String?** The Rails guides
   show `= "MyCustomDeliveryJob"`, but `ActionMailer::MessageDelivery` calls
   `.set(...)` on the value, which a String does not answer. Verify against
   actionmailer 8.1.3 at implementation time and use the constant if needed.
2. **`retry_on` attempt count** is left at ActiveJob's default of 5. COV-37 did not
   specify one; revisit if Loops 429s turn out to be sustained rather than bursty.

## More Info

### Corrections to the ticket's premises

Three of the ticket's stated facts do not match the repo, and two of its Open
Questions rest on them:

1. **Staging's queue adapter is `:async`, not `:inline`.**
   `config/environments/staging.rb:58`, with an AIDEV-NOTE explaining why —
   `:inline` raises `NotImplementedError` on `enqueue_at`, which
   `cancellation_reason`'s `deliver_later(wait: 1.hour)` hits.
2. **Staging sends nothing at all.** `config/environments/staging.rb:66` sets
   `perform_deliveries = false`, verified by COV-37 as a genuine kill switch
   (`Mail::Message#do_delivery` checks it *before* invoking the delivery method).
   Combined with (1), the ticket's "password reset is latency-sensitive and may run
   inline on staging" is wrong on both counts — mail never runs in a request thread
   in any environment. The timeouts are still worth setting, for job-thread reasons.
3. **The `loops_sdk` gem question is already closed.** COV-37 Decision 2 declined it
   with the gem's source read: it raises one generic `APIError` plus
   `RateLimitError`, uses a process-wide singleton config (no per-instance
   credentials), shadows `Object#send`, and treats 202/204 as errors. Nothing to
   approve, nothing to record in the PR.

### Facts confirmed against the Loops API reference

- Base URL `https://app.loops.so/api`; `Authorization: Bearer <key>`.
- `POST /v1/transactional` — `email` and `transactionalId` required;
  `addToAudience: true` creates a contact from `email`.
- `Idempotency-Key` header, max 100 characters. **Reuse returns 409; Loops does
  not replay the original response.**
- 400 = transactional email not published. 413 = payload too large.
  422 = LMX failed to compile. 429 = rate limited.
- Rate limit **10 requests/sec per team**, shared across transactional and
  marketing (COV-38 Decision 2 accepts that staging consumes production's budget).
  Responses carry `x-ratelimit-limit` and `x-ratelimit-remaining`.
- Most v1 transactional string values are capped at **500 characters**. Not
  enforced client-side — it surfaces as 400/422. A hard constraint on how
  COV-43/44/45 shape their payloads; no long-form content can pass through
  `dataVariables`.

Authoring-time codes (413 for LMX over 100 KB, 409 for a stale
`expectedRevisionId`) are unreachable from app code — authoring happens via the
CLI — so no handling is built for them beyond the generic classes.

### Repo details the plan will need

- `app/clients/` currently holds only `README.md` and is the intended home for
  host-app clients. `ApplicationClient` itself lives at
  `lib/jumpstart/app/clients/application_client.rb`.
- `ApplicationClient::NET_HTTP_ERRORS` (line 43) is the existing rescue list; the
  README pattern rescues it per-method. We do not rescue it in the client — the
  delivery job's `retry_on` handles timeouts instead.
- `test/clients/application_client_test.rb` is the pattern to follow:
  `ActiveSupport::TestCase`, `stub_request`, `assert_requested`.
- `lib/jumpstart/lib/generators/api_client/templates/` holds the generator's client
  and test templates, including the `self.client` credentials pattern reused above.
  `rails g api_client Loops` would scaffold the pair; the generated example
  endpoints get replaced.
- No `filter_parameters` change is needed —
  `config/initializers/filter_parameter_logging.rb` already includes `:_key`, which
  partial-matches `api_key`.
