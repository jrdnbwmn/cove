> Ticket: COV-49
> Branch: feature/cov-49-marketing-consent-model-preference-ui

# Plan: Marketing consent model and preference UI

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add nullable marketing-consent columns | Master | |
| 2 | 1 | 1 | Implement consent state and transitions | Master | |
| 3 | 2 | 2 | Capture consent during ordinary registration | Master | |
| 4 | 2 | 2 | Render and verify the registration control | subagent | |
| 5 | 3 | 3 | Add the authenticated preference endpoint | Master | |
| 6 | 3 | 3 | Add Marketing preferences to account settings | subagent | |
| 7 | 3 | 3 | Run integrated verification and final review | Master | |

## Prerequisites

- Design: [`docs/designs/cov-49-marketing-consent-preferences.md`](../designs/cov-49-marketing-consent-preferences.md)
- Prototype: None; preserve the existing registration and account-settings layouts
- Feature branch exists: `feature/cov-49-marketing-consent-model-preference-ui`
- Run Rails commands through mise, using `mise exec --`
- Use existing `CheckboxComponent`, `SwitchComponent`, and `ButtonComponent`; no component creation is required

## Tasks

### Task 1 [Master]: Add nullable marketing-consent columns

**Skills:** safe-migration, write-tests
**Reference:** Read [`db/migrate/20230717174558_add_preferences_to_users.rb`](../../db/migrate/20230717174558_add_preferences_to_users.rb) and the `users` definition in [`db/schema.rb`](../../db/schema.rb) for migration conventions

**In scope:**

- Add nullable `marketing_opt_in_at`, `marketing_opt_in_source`, `marketing_opt_out_at`, and `marketing_opt_out_reason` columns to `users`.
- Prove the columns have no defaults and existing/default users remain all-null.
- Verify migrate, rollback, and migrate again.

**NOT in scope:**

- No stored subscription boolean, indexes, data updates, defaults, Loops identifiers, API calls, or backfill jobs.

**Build order:**

1. **Test:** Add `test/migrations/add_marketing_consent_to_users_test.rb`. Assert each column exists with the expected datetime/string type, permits null, has no default, and leaves an existing fixture user's four values null. Run it first and confirm failure.
2. **Implement:** Run `mise exec -- bin/rails generate migration AddMarketingConsentToUsers marketing_opt_in_at:datetime marketing_opt_in_source:string marketing_opt_out_at:datetime marketing_opt_out_reason:string`. Keep the generated migration limited to those four nullable columns and update `db/schema.rb` through migration execution.
3. **Verify:** Run the focused migration test, then `mise exec -- bin/rails db:migrate`, `mise exec -- bin/rails db:rollback STEP=1`, and `mise exec -- bin/rails db:migrate`. Inspect all four schema dumps and revert only unrelated Rails 8.1 version/reordering drift.

### Task 2 [Master]: Implement consent state and transitions

**Skills:** write-tests
**Reference:** Read [`lib/jumpstart/app/models/user/agreements.rb`](../../lib/jumpstart/app/models/user/agreements.rb), [`app/models/user.rb`](../../app/models/user.rb), and [`test/fixtures/users.yml`](../../test/fixtures/users.yml)

**In scope:**

- Add `User::MarketingConsent` in `app/models/user/marketing_consent.rb` and include it from `User`.
- Define allowed sources (`registration`, `settings`, `loops`) and reasons (`user_app`, `user_loops`, `mailing_list_unsubscribe`, `hard_bounce`, `spam_report`) with inclusion validation.
- Add the typed virtual `marketing_opt_in` checkbox attribute, `marketing_subscribed?`, and the `marketing_subscribed` scope.
- Implement explicit grant/withdraw methods using `Time.current`, preserving timestamps and provenance on no-op saves.
- Permit deliberate reversal of `user_app`; protect the four non-app reasons from settings opt-in.
- Clear all consent fields when an email changes from `hard_bounce`; preserve `user_loops`, `mailing_list_unsubscribe`, and `spam_report`.
- Add intent-named `marketing_subscribed` and `marketing_unsubscribed` fixtures without repurposing the billing-oriented `subscribed` fixture.

**NOT in scope:**

- No controller, form, mailer, webhook, Loops client, synchronization job, or transactional-email condition.

**Build order:**

1. **Test:** Add `test/models/user/marketing_consent_test.rb`. Cover predicate/scope behavior, valid and invalid provenance, checked creation capture, opt-in/out transitions, no-op timestamp preservation, never-subscribed opt-out, reversible `user_app`, every protected reason, hard-bounce email reset, and preservation of the other protected states on email change.
2. **Implement:** Add the concern, include it in `app/models/user.rb`, and add the two fixtures. Expose the protected reason through a small query method so controllers and views use the same domain decision without embedding presentation text in the model.
3. **Verify:** Run `mise exec -- bin/rails test test/models/user/marketing_consent_test.rb test/migrations/add_marketing_consent_to_users_test.rb`. After Tasks 1–2 are complete, run `review-changes-mini` exactly once for Checkpoint 1; if executed as a batch, the Master runs it after both tasks return.

### Task 3 [Master]: Capture consent during ordinary registration

**Skills:** write-tests
**Reference:** Read [`lib/jumpstart/app/controllers/concerns/authentication.rb`](../../lib/jumpstart/app/controllers/concerns/authentication.rb), [`lib/jumpstart/app/controllers/users/registrations_controller.rb`](../../lib/jumpstart/app/controllers/users/registrations_controller.rb), and [`test/controllers/users/registrations_controller_test.rb`](../../test/controllers/users/registrations_controller_test.rb)

**In scope:**

- Permit `marketing_opt_in` for Devise sign-up only.
- Let checked ordinary registration record the current time and trusted `registration` source.
- Keep unchecked registration all-null.
- Ignore a crafted marketing parameter when a valid account invitation token is present.
- Confirm general profile updates cannot change consent through Devise's account-update parameters.

**NOT in scope:**

- No registration markup, invitation consent UI, account-settings endpoint, or changes to invitation acceptance behavior beyond ignoring marketing consent.

**Build order:**

1. **Test:** Extend `test/controllers/users/registrations_controller_test.rb` with checked, unchecked, and crafted-invitation registration cases. Also assert a profile update containing `marketing_opt_in` does not alter consent.
2. **Implement:** Add `marketing_opt_in` only to the `:sign_up` sanitizer and reset the virtual value when `Users::RegistrationsController` resolves a valid invitation.
3. **Verify:** Run `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb`.

### Task 4 [subagent]: Render and verify the registration control

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/devise/registrations/new.html.erb`](../../app/views/devise/registrations/new.html.erb) and the catalog entries for `CheckboxComponent` and `ButtonComponent` in [`docs/COMPONENT_CATALOG.md`](../../docs/COMPONENT_CATALOG.md)
**Prototype:** None — retain the existing field order and layout

**In scope:**

- Add an unchecked marketing checkbox between terms acceptance and Sign up.
- Render an explicit hidden `user[marketing_opt_in]` value of `"0"` immediately before the checkbox.
- Use the exact approved label.
- Preserve the submitted checked state after validation failure.
- Omit both inputs during invitation registration.
- Add the required registration translation.

**NOT in scope:**

- No layout redesign, new component, auto-save behavior, settings UI, Stimulus controller, or invitation consent capture.

**Build order:**

1. **Test:** Extend `test/controllers/users/registrations_controller_test.rb` with rendered-form assertions for default unchecked state, hidden/checkbox adjacency and order, exact label, preserved checked state after a failed submission, and complete absence for invitation registration.
2. **Implement:** Update `app/views/devise/registrations/new.html.erb` using `hidden_field_tag` plus `CheckboxComponent`, guarded by the absence of `@account_invitation`; add the label to `config/locales/devise.en.yml`.
3. **Verify:** Run `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb`. After Tasks 3–4 are complete, the Master runs `review-changes-mini` exactly once for Checkpoint 2.

### Task 5 [Master]: Add the authenticated preference endpoint

**Skills:** write-tests
**Reference:** Read [`config/routes/users.rb`](../../config/routes/users.rb), [`app/controllers/application_controller.rb`](../../app/controllers/application_controller.rb), and existing controller tests under `test/controllers/`

**In scope:**

- Add singular `marketing_preference` update routing to `MarketingPreferencesController#update`.
- Require authentication and always update `current_user`.
- Accept only explicit `"0"` or `"1"` from `marketing_preference[subscribed]`.
- Supply `settings` and `user_app` provenance on the server.
- Redirect to account settings with confirmation for successful changes and explanatory alerts for missing, invalid, or protected requests.
- Ignore forged user IDs, timestamps, sources, and reasons.
- Test on/off transitions, no-ops, reversible app opt-out, protected opt-ins, malformed parameters, authentication, and user isolation.

**NOT in scope:**

- No show/edit route, user ID route segment, browser-supplied provenance, Loops request, webhook, background job, or profile-controller reuse.

**Build order:**

1. **Test:** Add `test/controllers/marketing_preferences_controller_test.rb` covering authentication, route shape, current-user isolation, on/off/no-op behavior, invalid or missing state, forged provenance, and all protected opt-in outcomes.
2. **Implement:** Add `app/controllers/marketing_preferences_controller.rb`, the singular PATCH route in `config/routes/users.rb`, and controller feedback translations in `config/locales/en.yml`. Keep the action thin and delegate transitions to `User::MarketingConsent`.
3. **Verify:** Run `mise exec -- bin/rails test test/controllers/marketing_preferences_controller_test.rb`.

### Task 6 [subagent]: Add Marketing preferences to account settings

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/devise/registrations/edit.html.erb`](../../app/views/devise/registrations/edit.html.erb) and the catalog entries for `SwitchComponent` and `ButtonComponent` in [`docs/COMPONENT_CATALOG.md`](../../docs/COMPONENT_CATALOG.md)
**Prototype:** None — insert the section between Profile and Delete my account without rearranging either

**In scope:**

- Add a separate Marketing preferences heading and dedicated PATCH form.
- Render hidden `"0"` immediately before the `SwitchComponent`.
- Use the exact “Cove updates” label, description, and “Save marketing preferences” button.
- Derive checked state only from `current_user.marketing_subscribed?`.
- Disable both switch and button for `user_loops`, `mailing_list_unsubscribe`, `hard_bounce`, and `spam_report`.
- Render the exact approved explanation for each protected state.
- Keep `user_app` opt-outs enabled for deliberate reversal.
- Test section ordering, form isolation, hidden-field ordering, default state, subscribed state, reversible state, and every disabled protected state.

**NOT in scope:**

- No auto-save, new component, profile-form parameter, Loops read, new navigation item, or visual redesign.

**Build order:**

1. **Test:** Add `test/integration/marketing_preferences_ui_test.rb`. Assert the dedicated action/method and parameter namespace, hidden/switch sibling order, exact copy, submit button, section placement, subscribed/default rendering, enabled `user_app`, and disabled controls/messages for all protected reasons.
2. **Implement:** Update `app/views/devise/registrations/edit.html.erb` with the dedicated form and existing catalog components, using the translations added for the endpoint and protected-state copy.
3. **Verify:** Run `mise exec -- bin/rails test test/integration/marketing_preferences_ui_test.rb test/controllers/marketing_preferences_controller_test.rb`.

### Task 7 [Master]: Run integrated verification and final review

**Skills:** review-changes-mini
**Reference:** Re-read the acceptance criteria in [`docs/designs/cov-49-marketing-consent-preferences.md`](../designs/cov-49-marketing-consent-preferences.md)

**In scope:**

- Verify the complete consent feature and repository quality gates.
- Review every changed file for scope, hidden-field ordering, trusted provenance, protected states, and transactional-email isolation.
- Remove only COV-49 regressions or artifacts discovered by verification.

**NOT in scope:**

- No Loops work, unrelated refactoring, dependency changes, speculative improvements, or unrelated schema cleanup.

**Build order:**

1. **Test:** Run `mise exec -- bin/rails test`.
2. **Implement:** If a COV-49 failure appears, make the smallest scoped correction, add or adjust its focused regression test first, and rerun that focused test. Confirm no authentication/security mailer was made conditional on marketing consent.
3. **Verify:** Run `mise exec -- bin/rails test`, `mise exec -- bin/rubocop`, `git diff --check`, `git status --short`, and the full `git diff`. Revert only unrelated Rails 8.1 drift in `db/schema.rb`, `db/cable_schema.rb`, `db/cache_schema.rb`, or `db/queue_schema.rb`. After Tasks 5–7 and both feature tracks are complete, run `review-changes-mini` exactly once for Checkpoint 3.

## Task Dependencies

- Task 2 depends on Task 1 because the concern needs the new columns.
- Task 3 depends on Task 2 because registration delegates consent capture to the concern.
- Task 4 depends on Task 3 because the rendered control relies on the permitted virtual attribute and invitation guard.
- Task 5 depends on Task 2 and is otherwise independent of the registration track.
- Once Task 3 is complete, Task 4 can run in a subagent while the Master executes Task 5.
- Task 6 depends on Task 5 and can run in a subagent after the endpoint and translations exist.
- Task 7 depends on Tasks 4 and 6 and runs only after both UI tracks return.
