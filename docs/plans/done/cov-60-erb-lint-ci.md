> Ticket: COV-60
> Branch: jrdnbwmn/feature/cov-60-wire-erb-lint-ci

# Plan: Wire erb_lint into CI

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Create `bin/erb_lint` binstub | Master | |
| 2 | 1 | 1 | Autocorrect the 44 `SpaceInHtmlTag` offenses (own commit) | Master | |
| 3 | 1 | 2 | Hand-fix the 4 `RequireInputAutocomplete` offenses | Master | |
| 4 | 1 | 2 | Wire the step into `ci.yml` + `config/ci.rb`, verify | Master | |

## Prerequisites

- Design: `docs/designs/cov-60-erb-lint-ci.md`
- Prototype: None
- Feature branch exists: `jrdnbwmn/feature/cov-60-wire-erb-lint-ci`
- **Every task must start with** `export PATH="$HOME/.local/share/mise/shims:$PATH"` and confirm `ruby -v` reports 4.0.5 before trusting any output (AGENTS.md).

## Tasks

### Task 1 [Master]: Create `bin/erb_lint` binstub

**Skills:** none
**Reference:** Read `bin/rubocop` — mirror its structure exactly.

**In scope:**

- New file `bin/erb_lint`, contents verbatim from the design (§Scope 1):
  ```ruby
  #!/usr/bin/env ruby
  require "rubygems"
  require "bundler/setup"

  ARGV.unshift("--config", File.expand_path("../.erb_lint.yml", __dir__))

  load Gem.bin_path("erb_lint", "erb_lint")
  ```
- `chmod +x bin/erb_lint`

**NOT in scope:**

- Hardcoding `--lint-all` into the binstub — that breaks single-file runs.
- Using the `erblint` exe name — it's deprecated and warns.
- Any edit to `.erb_lint.yml`.

**Build order:**

1. **Test:** None. Per design §"No test file" — do NOT write a test file for this ticket.
2. **Implement:** Write `bin/erb_lint`, then `chmod +x bin/erb_lint`.
3. **Verify:** `bin/erb_lint --lint-all -f compact` runs and reports the expected 48 offenses (44 `SpaceInHtmlTag` + 4 `RequireInputAutocomplete`). The `parser/current ... 3.3.x` stderr warning is expected upstream noise — ignore it, do not try to fix it.

---

### Task 2 [Master]: Autocorrect the 44 whitespace offenses

**Skills:** none
**Reference:** Design §Scope 2 for the 14-file table.

**In scope:**

- Run `bin/erb_lint --lint-all -a`.
- Confirm the diff touches exactly the 14 files listed in the design's table and contains **only** whitespace changes inside `<...>` tags.
- Commit this on its own: `git commit -m "style: autocorrect ERB whitespace offenses"`. Nothing else in this commit.

**NOT in scope:**

- Any hand-editing. If autocorrect leaves a `SpaceInHtmlTag` offense behind, STOP and report rather than fixing by hand.
- The 4 `RequireInputAutocomplete` offenses — `-a` cannot fix those; they're Task 3.
- Touching `lib/jumpstart/**` — those 178 files are already clean; if the diff shows any, STOP and report.

**Build order:**

1. **Test:** None.
2. **Implement:** `bin/erb_lint --lint-all -a`
3. **Verify:**
   - `git diff --stat` shows 14 files, all under `app/components/` or `app/views/application/`.
   - `git diff` contains no text-node changes.
   - `bin/erb_lint --lint-all -f compact` now reports exactly 4 offenses, all `RequireInputAutocomplete`.
   - Commit.
4. **Checkpoint review:** This is the last task of Checkpoint 1 (Tasks 1–2). Run review-changes-mini covering both tasks before moving on. If this checkpoint's tasks were executed as a parallel batch, the master runs this review once the whole batch returns rather than the task running it itself — either way it runs exactly once, after every task in the checkpoint is done.

---

### Task 3 [Master]: Hand-fix the 4 autocomplete offenses

**Skills:** none
**Reference:** Design §Scope 3 table. Lines verified as of planning:

| File:line | Field | Change |
|---|---|---|
| `app/views/dev/kitchen_sink/show.html.erb:17` | Display name | add `autocomplete="nickname"` to the raw `<input>` |
| `app/views/dev/kitchen_sink/show.html.erb:31` | Email | add `autocomplete="email"` to the raw `<input>` |
| `app/views/dev/kitchen_sink/show.html.erb:37` | Account ID | add `autocomplete="off"` to the raw `<input>` |
| `app/components/pagination_component.html.erb:34` | Jump to Page | add `autocomplete: "off"` to the `number_field_tag` options hash |

**In scope:**

- Exactly those 4 attribute additions, in 2 files.
- `nickname` (not `off`) on Display name and `email` on Email — deliberate deviation from the ticket, because the kitchen sink is the copy-paste showcase and should model correct habits.

**NOT in scope:**

- Converting the kitchen sink's raw `<input>` tags to Rails form helpers. Out of scope for this ticket even though the rules generally prefer helpers — these are intentional showcase markup.
- Any other visual or structural change to either file.
- Adding `autocomplete` to inputs that aren't flagged.

**Build order:**

1. **Test:** None.
2. **Implement:** The 4 edits above. Note line numbers may have shifted by Task 2's autocorrect — match on the field's `id`/`name` attribute, not the line number.
3. **Verify:** `bin/erb_lint --lint-all -f compact` exits 0 with 0 offenses.

---

### Task 4 [Master]: Wire the step into CI and verify end-to-end

**Skills:** none
**Reference:** `.github/workflows/ci.yml:23-30` (the `lint` job), `config/ci.rb:6`.

**In scope:**

- `.github/workflows/ci.yml` — one line appended to the **existing** `lint` job, after `- run: bin/rubocop -f github`:
  ```yaml
      - run: bin/erb_lint --lint-all -f compact
  ```
- `config/ci.rb` — one step immediately after `step "Style: Ruby", "bin/rubocop"`:
  ```ruby
  step "Style: ERB", "bin/erb_lint --lint-all -f compact"
  ```
- Commit 2: these two files + `bin/erb_lint` (Task 1) + the 2 files from Task 3.
  `git commit -m "feature: wire erb_lint into CI"`

**NOT in scope:**

- A new CI job, an extra `bundle install`, or changes to the `security` / `test` / `system` / `seeds` jobs.
- A `-f github` formatter — erb_lint has no such formatter (formats are `compact, gitlab, json, junit, multiline`), so there will be no inline PR annotations. That's accepted.
- A pre-commit hook, or widening the lint glob to `.text.erb` / `.turbo_stream.erb`.

**Build order:**

1. **Test:** None.
2. **Implement:** The two one-line additions.
3. **Verify** — run all of these and show output:
   - `bin/erb_lint --lint-all -f compact` → 0 offenses, exit 0.
   - Deliberate-offense check: add an extra space inside a tag in any `.html.erb`, confirm `bin/erb_lint --lint-all` exits non-zero, then **revert it** (`git checkout --` that file).
   - `bin/rails test` → passes.
   - `bin/rails test:system` → passes.
   - Spot-check `/dev/kitchen_sink` renders correctly. Per AGENTS.md, `ApplicationController.render` won't work here — boot a temporary server and hit the page, or use browser automation.
   - `git diff origin/main...` to confirm the total change is the 19 expected files and nothing else.
4. **Checkpoint review:** Last task of Checkpoint 2 (Tasks 3–4). Run review-changes-mini covering both tasks before committing. If this checkpoint's tasks were executed as a parallel batch, the master runs this review once the whole batch returns rather than the task running it itself — either way it runs exactly once, after every task in the checkpoint is done.

## Task Dependencies

- Task 2 depends on Task 1 (needs the binstub; alternatively `bundle exec erb_lint --lint-all -a --config .erb_lint.yml`).
- Task 3 depends on Task 2 (line numbers shift after autocorrect).
- Task 4 depends on Task 3 (the "0 offenses" verification requires all fixes landed).
- **No parallelism** — the chain is strictly sequential. All tasks are Master: the work touches shared CI infra and is too small to be worth clone overhead.

**Commit structure** (design §Commit structure): two commits, not one.

1. Task 2's autocorrect alone — skimmable, zero hand-editing.
2. Tasks 1 + 3 + 4 — the reviewable commit.
