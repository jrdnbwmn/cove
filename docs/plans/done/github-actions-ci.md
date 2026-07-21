> Ticket: COV-29
> Branch: feature/cov-29-github-actions-ci

# Plan: GitHub Actions CI + branch protection on `main`

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Owner adds `RAILS_MASTER_KEY` repo secret | Master (user action) | ✅ |
| 2 | Local eager-load pre-flight (`zeitwerk:check` + `CI=true`) | Master | ✅ |
| 3 | Write `.github/workflows/ci.yml` (five jobs) | Master | ✅ |
| 4 | Push branch, open PR, iterate until all five jobs green | Master | ✅ |
| 5 | Owner merges; owner enables branch protection on `main` | Master (user action) | ✅ |
| 6 | Proof PR — verify the three failure paths block merge | Master | ✅ |
| 7 | Verify `git push origin main` is refused + `bin/ci` clean locally | Master | ✅ |

Every task is Master. There is exactly one source file in this change and the
rest is GitHub-side verification that needs judgment on live CI output —
nothing here decomposes into independently verifiable clone work.

## Prerequisites

- Design: `docs/designs/github-actions-ci.md`
- Prototype: None
- Feature branch `feature/cov-29-github-actions-ci` exists and is checked out
- `gh` CLI authenticated as `jrdnbwmn`, remote is `git@github.com:jrdnbwmn/cove.git`
- `.github/` does not exist yet — Task 3 creates the directory

## Tasks

### Task 1 [Master]: Owner adds the `RAILS_MASTER_KEY` repo secret

**Skills:** none
**Reference:** `config/credentials/test.key` (gitignored, 32 chars),
`config/environments/test.rb:56` (`config.require_master_key = true`)

**In scope:**

- Stop and ask Jordan to add the secret before anything is pushed. GitHub →
  repo Settings → Secrets and variables → Actions → New repository secret.
  Name: `RAILS_MASTER_KEY`. Value: the contents of `config/credentials/test.key`.
- Print the key value to the terminal for copy/paste (it's a dummy test-only
  key, but do not commit it or echo it into any file).
- Wait for explicit confirmation that the secret exists before starting Task 4.

**NOT in scope:**

- Committing `config/credentials/test.key` (rejected in design — preserves the
  "no keys in git" invariant).
- Setting the secret via `gh secret set` on Jordan's behalf — this is an
  account-settings change; ask, don't do.

**Build order:**

1. **Implement:** `cat config/credentials/test.key`, relay to Jordan with the
   exact steps above.
2. **Verify:** Jordan confirms in chat. Optionally `gh secret list` to see
   `RAILS_MASTER_KEY` listed (names are visible, values are not).
3. **Review:** n/a — no code changed.

---

### Task 2 [Master]: Local eager-load pre-flight

**Skills:** none
**Reference:** `config/environments/test.rb:16` —
`config.eager_load = ENV["CI"].present?`

**In scope:**

- Catch eager-load/autoload failures locally instead of burning CI runs on
  them. The design flags this explicitly: CI sets `CI=true`, so the app
  eager-loads in CI but never does locally under `bin/ci`.
- Run, with mise shims on PATH
  (`export PATH="$HOME/.local/share/mise/shims:$PATH"`):
  - `bin/rails zeitwerk:check`
  - `CI=true RAILS_ENV=test bin/rails runner "Rails.application.eager_load!; puts :ok"`
- Fix any load errors surfaced. If a fix is more than a trivial require/naming
  correction, STOP and report to Jordan rather than refactoring.

**NOT in scope:**

- Any refactor beyond making the app eager-load cleanly.
- Touching `config/ci.rb` or `bin/ci` — untouched for the whole plan.

**Build order:**

1. **Verify:** both commands above, output shown in the message.
2. **Review:** if any file changed, run review-changes before proceeding. This
   is not optional.

---

### Task 3 [Master]: Write `.github/workflows/ci.yml`

**Skills:** none (pure infra; no Rails code, no migration, no UI)
**Reference:** `config/ci.rb` for the command list, `config/database.yml:20-25`
for the `DB_HOST` block, `.ruby-version` (4.0.5 — never hardcode it in the
workflow)

**In scope:**

- Create `.github/workflows/ci.yml`, exactly as specified in the design's
  *Workflow Design* section. One new file; nothing else changes.
- Shared header: `name: CI`; `on: pull_request` + `push: branches: [main]`;
  `concurrency` group `${{ github.workflow }}-${{ github.ref }}` with
  `cancel-in-progress: true`; workflow-level
  `env: RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}`.
- Five jobs, all `runs-on: ubuntu-latest`, each starting with
  `actions/checkout@v6` then `ruby/setup-ruby@v1` with
  `ruby-version-file: .ruby-version` and `bundler-cache: true`:
  - `lint` — `bin/rubocop -f github`
  - `security` — `bin/bundler-audit`, then `bin/importmap audit`, then
    `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
  - `test` — `bin/rails db:test:prepare`, `bin/rails test`
  - `system` — `bin/rails db:test:prepare`, `bin/rails test:system`
  - `seeds` — `bin/rails db:test:prepare`, `bin/rails db:seed:replant`
- `test`, `system`, `seeds` get the Postgres service block from the design:
  `postgres:17`, `POSTGRES_USER`/`POSTGRES_PASSWORD` = `postgres`, port
  `5432:5432`, `pg_isready` health options; plus job-level
  `env: DB_HOST: localhost, RAILS_ENV: test`.
- `system` ends with `actions/upload-artifact@v4`, `if: failure()`,
  `name: screenshots`, `path: tmp/screenshots`, `if-no-files-found: ignore`.
- Two `AIDEV-NOTE:` comments in the YAML, per the design's findings: (a) no
  Tailwind build step is needed because `test:prepare` is enhanced by
  tailwindcss-rails' `tailwindcss:build`; (b) no apt packages and no
  `setup-chrome` — `pg` and `tailwindcss-ruby` ship precompiled `x86_64-linux`
  in `Gemfile.lock`, and `ubuntu-latest` ships Chrome for Selenium Manager.

**NOT in scope:**

- Editing `config/ci.rb` or `bin/ci` — they stay the local source of truth.
- Path filters on triggers (a required check that never runs blocks a PR
  permanently).
- A composite setup action, a sharded test matrix, a RuboCop cache,
  Dependabot, or any deploy/CD workflow — all explicitly deferred.
- Hardcoding a Ruby version, or dropping `--ensure-latest` from `bin/brakeman`
  (fidelity with local `bin/ci` is deliberate).

**Build order:**

1. **Implement:** write `.github/workflows/ci.yml`.
2. **Verify:** parse it —
   `ruby -ryaml -e 'p YAML.safe_load_file(".github/workflows/ci.yml", aliases: true).keys'`
   — and re-read the file against the design's job table to confirm the five
   job ids are literally `lint`, `security`, `test`, `system`, `seeds` (these
   strings become the required-check names in Task 5).
3. **Review:** ALWAYS run review-changes before proceeding. This is not
   optional.

---

### Task 4 [Master]: Push, open the PR, drive it green

**Skills:** none
**Reference:** design §Rollout Order step 3

**In scope:**

- Commit the workflow (`feature: add GitHub Actions CI workflow`), push the
  branch, open the PR against `main` with `gh pr create`.
- Watch the run (`gh run watch` / `gh run view --log-failed`). Expect this
  first run to surface things that have never failed locally — eager-load
  errors above all, and possibly Chrome/Selenium behavior in `system`.
- Fix failures on this branch and re-push until all five jobs are green.
- If a failure would require changing app behavior rather than CI config,
  STOP and report to Jordan with the log — don't silently patch app code to
  make CI pass.

**NOT in scope:**

- Merging the PR. Jordan reviews and merges every ticket PR.
- Enabling branch protection yet — GitHub can't offer a check as required
  until it has seen it report once.

**Build order:**

1. **Implement:** commit → push → `gh pr create`.
2. **Verify:** `gh pr checks` shows all five green. Paste the actual output.
3. **Review:** review-changes on any fix commits.

---

### Task 5 [Master]: Merge, then owner enables branch protection

**Skills:** none
**Reference:** design §Branch Protection

**In scope:**

- Ask Jordan to review and merge the PR (direct merge works — `main` is still
  unprotected at this point).
- Then relay the exact branch-protection settings for Jordan to apply in the
  GitHub UI: Settings → Branches → **Add classic branch protection rule**.
  - Pattern `main`
  - Require a pull request before merging, **"Require approvals" unchecked**
    (0 approvals, solo maintainer)
  - Require status checks to pass → select all five: `lint`, `security`,
    `test`, `system`, `seeds`
  - Do NOT check "Require branches to be up to date before merging"
  - Do NOT check require conversation resolution / signed commits / linear
    history
  - **Do not allow bypassing the above settings** — checked
  - Leave force-push and deletion disallowed (defaults)
- Wait for Jordan's confirmation before Task 6.

**NOT in scope:**

- Claude merging the PR, or applying protection via `gh api`. Both are
  account/repo settings changes and Jordan's call — relay the steps, don't
  execute them.
- Rulesets (classic protection is what the design chose).

**Build order:**

1. **Implement:** relay merge request, then relay the settings checklist
   verbatim.
2. **Verify:** Jordan confirms;
   `gh api repos/jrdnbwmn/cove/branches/main/protection` (read-only) shows the
   five contexts.
3. **Review:** n/a.

---

### Task 6 [Master]: Proof PR — verify the failure paths

**Skills:** none
**Reference:** design §Verification

**In scope:**

- One throwaway branch (`chore/ci-proof`, not a ticket branch) carrying three
  deliberate breaks:
  1. a RuboCop offense,
  2. a failing assertion in an existing model test,
  3. a failing assertion in an existing **system** test, placed *after* page
     load so a screenshot is actually captured.
- Open a PR, confirm: `lint`/`test`/`system` go red, the merge button is
  blocked by protection, and the `screenshots` artifact is downloadable from
  the `system` run.
- Then close the PR **unmerged** and delete the branch. Nothing from it
  reaches `main`.

**NOT in scope:**

- Merging it, or leaving the branch behind.
- Proving `security` or `seeds` failure paths — not in the acceptance
  criteria.

**Build order:**

1. **Implement:** branch from merged `main`, introduce the three breaks, push,
   `gh pr create`.
2. **Verify:** `gh pr checks` shows the three red;
   `gh run download --name screenshots` retrieves the artifact;
   screenshot/quote the blocked merge button.
3. **Cleanup:** `gh pr close`, delete local and remote branch.
4. **Review:** n/a — nothing merges.

---

### Task 7 [Master]: Final verification on `main`

**Skills:** none

**In scope:**

- On merged, protected `main`: attempt a real `git push origin main` (a
  trivial no-op-able commit) and confirm the server **refuses** it — this is
  the acceptance criterion, and it must actually be attempted, not assumed.
  Reset the local commit afterward.
- Run `bin/ci` locally on `main` and confirm it's still clean (`config/ci.rb`
  and `bin/ci` were never touched).
- Report every acceptance-criterion checkbox with the evidence that closed it.

**NOT in scope:**

- Any `--force` anything.

**Build order:**

1. **Verify:** the push attempt (output shown), then
   `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/ci` (output
   shown).
2. **Review:** n/a.

## Task Dependencies

- Strictly sequential, 1 → 7. Nothing here parallelizes.
- Task 1 (secret) is a hard gate on Task 4 — without it, `test`/`system`/
  `seeds` die at boot on `require_master_key`.
- Task 2 before Task 3 only to save CI cycles; if you skip it, its failures
  reappear in Task 4 anyway.
- Task 5 (protection) **must** come after Task 4's run has reported, or the
  five check names won't be selectable.
- Task 6 depends on protection existing — the whole point is proving merge is
  blocked.

## Notes / Risks

- **`bin/brakeman --ensure-latest` is a known time bomb.** A Brakeman release
  unrelated to this codebase turns `security` red and blocks all merges until
  `bundle update brakeman`. Kept deliberately for local/CI parity; if it
  fires, the fix is a `bundle update brakeman` PR, not a workflow edit.
- **Semantic-conflict window is accepted.** "Require branches to be up to
  date" is off, so two individually-green PRs can merge into a broken `main`.
  The `push: [main]` trigger catches it within minutes.
- **Three of seven tasks are Jordan's to execute** (secret, merge, branch
  protection). Claude relays instructions and waits; it does not touch repo
  settings.
