> Ticket: COV-90
> Branch: feature/cov-90-free-tier-restrictions

# Plan: Raise Free student limit to 2

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Free limit 2, validation minimum, AIDEV-NOTE | Master | ✅ |
| 2 | 1 | 1 | Pricing cards: "2 students" / "Unlimited students" | Clone | ✅ |
| 3 | 1 | 2 | "More than N students? Contact us." line on /pricing | Clone | ✅ |
| 4 | 1 | 2 | Billing Free description + typography sample | Clone | ✅ |
| 5 | 2 | 3 | Cancel notice: immediate wording for past_due/unpaid | Clone | ✅ |
| 6 | 2 | 3 | Cancel page hides resume line when canceling immediately | Clone | ✅ |
| 7 | 2 | 3 | Product brief update | Master | ✅ |

## Prerequisites

- Design: `docs/designs/free-student-limit-two.md`
- Prototype: None
- Feature branch exists: `feature/cov-90-free-tier-restrictions`
- Every shell running `bin/rails` first runs `export PATH="$HOME/.local/share/mise/shims:$PATH"`; `ruby -v` should report 4.0.5.

## Tasks

### Task 1 [Master]: Free limit 2, validation minimum, AIDEV-NOTE

**Skills:** write-tests
**Reference:** Read `app/models/account.rb` and `test/models/account_test.rb:166-311` for patterns to follow

**In scope:**

- `FREE_STUDENT_LIMIT = 2` in `app/models/account.rb`.
- `student_limit` validation: `greater_than_or_equal_to: FREE_STUDENT_LIMIT` (was `1`).
- Replace the `students_allowed` AIDEV-NOTE with: Premium is advertised as unlimited, but `student_limit` (default 10, raised per family by a superadmin) is the real cap that keeps co-ops and micro-schools off a family plan; families above it contact support. No per-student fee — pricing stays flat per family and Stripe quantity never changes.

**NOT in scope:**

- Any change to `students_allowed` logic, migrations, the Madmin form, copy/views.

**Build order:**

1. **Test:** `test/models/account_test.rb` — assert literal numbers, not the constant:
   - Change every `assert_equal 1, account.students_allowed` (6 places) to `2`.
   - Rename "a new family is free and allowed one student" → "a new Free family can have 2 students".
   - Add "a superadmin-raised Premium family can have its raised number": `accounts(:complimentary).update!(student_limit: 14)`; assert `students_allowed == 14`.
   - Rename "a family rejects student limits below one or with decimals" → "a family's student limit can't be below the Free limit or a decimal"; add `1` to the invalid list; add an assertion that `student_limit = 2` is valid.
   - Run; confirm failures.
2. **Implement:** the `app/models/account.rb` changes above.
3. **Verify:** `bin/rails test test/models/account_test.rb test/integration/madmin/accounts_test.rb test/helpers/plan_pricing_helper_test.rb`

### Task 2 [Clone]: Pricing cards say "2 students" and "Unlimited students"

**Skills:** write-tests
**Reference:** Read `app/views/pricing/_free_card.html.erb`, `app/views/pricing/_premium_card.html.erb`, `config/locales/en.yml:259-277`, `test/integration/public_test.rb:86-92` for patterns to follow

**In scope:**

- `en.yml` under `pricing.show`: replace both `features:` arrays with explicit keys (Rails can't pluralize array items):
  ```yaml
  free:
    students:
      one: "%{count} student"
      other: "%{count} students"
    both_parents: "Both parents"
  premium:
    students: "Unlimited students"
    both_parents: "Both parents"
  ```
- `_free_card.html.erb`: `features: [t("pricing.show.free.students", count: Account::FREE_STUDENT_LIMIT), t("pricing.show.free.both_parents")]`
- `_premium_card.html.erb`: `features: [t("pricing.show.premium.students"), t("pricing.show.premium.both_parents")]` — no longer passes `premium_student_limit`.

**NOT in scope:**

- The contact line (Task 3), `PlanCardComponent`, the kitchen sink plan-card example.

**Build order:**

1. **Test:** `test/integration/public_test.rb`:
   - Update the existing "both parents" test to use `I18n.t("pricing.show.free.both_parents")` instead of `features.last`.
   - Add "the Free pricing card says 2 students": `get pricing_path`; `assert_includes response.body, ">2 students<"`.
   - Add "the Premium pricing card shows unlimited students": includes `">Unlimited students<"`; `assert_not_includes response.body, "Up to"`.
   - Run; confirm failures.
2. **Implement:** `config/locales/en.yml`, `app/views/pricing/_free_card.html.erb`, `app/views/pricing/_premium_card.html.erb`.
3. **Verify:** `bin/rails test test/integration/public_test.rb test/integration/plans_test.rb test/components/plan_card_component_test.rb`
4. **Checkpoint 1 review:** When this task's work is finished, run **review-changes-mini** covering Checkpoint 1 (Tasks 1–2). If the checkpoint's tasks were executed as a parallel batch, the master runs this review once the whole batch returns, rather than this task running it itself. Either way it runs exactly once per checkpoint, after every task in the checkpoint is done.

### Task 3 [Clone]: "More than N students? Contact us." on /pricing

**Skills:** write-tests
**Reference:** Read `app/views/pricing/show.html.erb`, `app/views/checkouts/show.html.erb:107` (`mail_to` pattern), `app/helpers/plan_pricing_helper.rb` for patterns to follow

**In scope:**

- `en.yml` under `pricing.show`:
  ```yaml
  more_students_html: "More than %{student_limit} students? %{link}."
  more_students_contact: "Contact us"
  more_students_subject: "More students on %{product}"
  ```
- `app/views/pricing/show.html.erb`, directly after the `no_refunds` paragraph:
  ```erb
  <p class="mt-2 text-center text-sm text-muted-foreground"><%= t(".more_students_html", student_limit: premium_student_limit, link: mail_to(Jumpstart.config.support_email, t(".more_students_contact"), subject: t(".more_students_subject", product: Jumpstart.config.application_name), class: "underline text-foreground hover:text-primary")) %></p>
  ```

**NOT in scope:**

- Linking to `support_path` (requires sign-in; `/pricing` is public). Showing the line on checkout or billing. Changing `premium_student_limit`.

**Build order:**

1. **Test:** `test/integration/public_test.rb`:
   - "a signed-out visitor is invited to contact support for more than 10 students": `get pricing_path`; includes `"More than 10 students?"`; `assert_select "a[href^=?]", "mailto:#{Jumpstart.config.support_email}", text: "Contact us"`.
   - "a raised Premium family sees its own number in the contact line": `accounts(:complimentary).update!(student_limit: 14)`; `sign_in users(:complimentary)`; `get pricing_path`; includes `"More than 14 students?"`.
   - Run; confirm failures.
2. **Implement:** `config/locales/en.yml`, `app/views/pricing/show.html.erb`.
3. **Verify:** `bin/rails test test/integration/public_test.rb test/integration/plans_test.rb` (the enterprise `mailto:user@example.com` assertion in `plans_test.rb` must still pass).

### Task 4 [Clone]: Billing Free description and typography sample

**Skills:** write-tests
**Reference:** Read `app/views/billing/_plan_state.html.erb:6`, `app/views/dev/typography/show.html.erb:27-30`, `test/integration/subscriptions_test.rb:20-25` (`payments_enabled?` stub) for patterns to follow

**In scope:**

- `en.yml` `billing.show.free_description` → `one: "Your Family can have %{count} student."` / `other: "Your Family can have %{count} students."`; `_plan_state.html.erb` passes `count: Account::FREE_STUDENT_LIMIT`.
- New key `dev.typography.show.pricing_sample` with `one`/`other`: "Free forever for %{count} student[s]. Upgrade to Premium for unlimited students and both parents, $12/month or $120/year." Replace the hard-coded sentence in `dev/typography/show.html.erb` with `t("dev.typography.show.pricing_sample", count: Account::FREE_STUDENT_LIMIT)`.

**NOT in scope:**

- Premium or complimentary billing copy; any other typography page text.

**Build order:**

1. **Test:** `test/integration/billing_policy_copy_test.rb` — add "the billing page tells a Free family it can have 2 students": inside `Jumpstart.config.stub(:payments_enabled?, true)`, `sign_in users(:one)`, `get billing_path`, `assert_includes response.body, "Your Family can have 2 students."`. Run; confirm it fails. (Typography page: no test, per approved design A3.)
2. **Implement:** `config/locales/en.yml`, `app/views/billing/_plan_state.html.erb`, `app/views/dev/typography/show.html.erb`.
3. **Verify:** `bin/rails test test/integration/billing_policy_copy_test.rb test/integration/subscriptions_test.rb`; then curl `/dev/typography` on a temporary dev server and confirm it renders "Free forever for 2 students".
4. **Checkpoint 2 review:** When this task's work is finished, run **review-changes-mini** covering Checkpoint 2 (Tasks 3–4). If the checkpoint's tasks were executed as a parallel batch, the master runs this review once the whole batch returns, rather than this task running it itself. Either way it runs exactly once per checkpoint, after every task in the checkpoint is done.

### Task 5 [Clone]: Cancel notice says "immediately" for past_due and unpaid

**Skills:** write-tests
**Reference:** Read `app/helpers/account_deletion_helper.rb:18-26`, `app/controllers/billing/subscriptions/cancels_controller.rb:11-23`, `test/helpers/account_deletion_helper_test.rb` for patterns to follow

**In scope:**

- `AccountDeletionHelper#cancels_immediately?(subscription)`: `subscription.metered? || subscription.past_due? || subscription.unpaid?`, with an `# AIDEV-NOTE:` that it mirrors the `cancel_now!` branches in `Billing::Subscriptions::CancelsController#destroy` and the two must stay in sync.
- `cancellation_end_notice` uses `cancels_immediately?` for its first branch (was `metered?`).
- `en.yml` `billing.subscriptions.cancels.show.cancel_immediately` → "Your plan will be canceled immediately. No refund is issued."

**NOT in scope:**

- Changing `CancelsController`, the cancel view (Task 6), `pricing.show.no_refunds`.

**Build order:**

1. **Test:** `test/helpers/account_deletion_helper_test.rb`:
   - "a past due family is told canceling ends the plan immediately": `pay_subscriptions(:past_due)` — `cancels_immediately?` true; notice equals `I18n.t("billing.subscriptions.cancels.show.cancel_immediately")`.
   - Same for `pay_subscriptions(:unpaid)`.
   - "an active family is told the plan ends at period end": `pay_subscriptions(:subscribed)` — `cancels_immediately?` false; notice is the dated `active_until_no_refund` text for "October 15, 2026".
   - Run; confirm failures.
2. **Implement:** `app/helpers/account_deletion_helper.rb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/helpers/account_deletion_helper_test.rb`

### Task 6 [Clone]: Cancel page hides "resume" when canceling immediately

**Skills:** write-tests
**Reference:** Read `app/views/billing/subscriptions/cancels/show.html.erb:17-18`, `test/integration/billing_policy_copy_test.rb` for patterns to follow

**In scope:**

- `app/views/billing/subscriptions/cancels/show.html.erb`: wrap `<div><%= t(".resume") %></div>` in `<% unless cancels_immediately?(@subscription) %>`.

**NOT in scope:**

- Any other cancel page copy or layout; the controller.

**Build order:**

1. **Test:** `test/integration/billing_policy_copy_test.rb`:
   - "a past due family's cancel page says the plan ends immediately and offers no resume": `sign_in users(:past_due)`; `get billing_subscription_cancel_path(pay_subscriptions(:past_due))`; includes the `cancel_immediately` text; does not include `I18n.t("billing.subscriptions.cancels.show.resume")`.
   - "an active family's cancel page still offers resuming": `sign_in users(:subscribed)`; resume text present.
   - Run; confirm failures.
2. **Implement:** `app/views/billing/subscriptions/cancels/show.html.erb`.
3. **Verify:** `bin/rails test test/integration/billing_policy_copy_test.rb`, then (sequentially, nothing else running) `bin/rails test:system test/system/pricing_and_billing_system_test.rb`.

### Task 7 [Master]: Product brief matches the decisions

**Skills:** —
**Reference:** Read the "Brief — `docs/product/product-brief.md`" section of `docs/designs/free-student-limit-two.md`

**In scope:**

- Keep the existing "Students will eventually have their own logins" line.
- Free vs Premium table: Students → `2` | `Unlimited (advertised); 10-student cap, raisable per family`.
- Students: Free 2 settled (remove "planned" / "the app still enforces 1"); Premium advertised unlimited, real cap is `student_limit` (default 10, superadmin-raisable), contact support above it; no per-student fee, no Stripe quantity or pricing-structure change, flat per family; keep the "past the limit" bullet; the five downgrade rules, marked "built in the Students ticket".
- Billing behavior: canceling while `past_due`/`unpaid` ends Premium immediately (`CancelsController` calls `cancel_now!`; intended; the cancel page says so). Yearly → monthly takes effect at renewal, no proration or credit (built in the "Yearly → monthly takes effect at renewal" ticket).
- Open questions: only Terms of Service and refund policy pages.

**NOT in scope:**

- `strategy-brief.md`, `ux-notes.md`.

**Build order:**

1. **Implement:** edit `docs/product/product-brief.md`.
2. **Verify:** reread against the design doc's brief section; run full `bin/rails test` and show the output.
3. **Checkpoint 3 review:** When this task's work is finished, run **review-changes-mini** covering Checkpoint 3 (Tasks 5–7). If the checkpoint's tasks were executed as a parallel batch, the master runs this review once the whole batch returns, rather than this task running it itself. Either way it runs exactly once per checkpoint, after every task in the checkpoint is done.

## Task Dependencies

- Tasks 2, 3, 4 depend on Task 1 (their tests assert "2 students").
- **Tasks 2 → 3 → 4 → 5 run sequentially**: all edit `config/locales/en.yml`, and Tasks 2 and 3 both edit `test/integration/public_test.rb`.
- Task 6 depends on Task 5 (`cancels_immediately?`).
- Task 7 (docs only) can run in parallel with any task after Task 1.
- Keep Rails test runs sequential; Task 6's system test must not run alongside another test process.
