> Plan created: docs/plans/cov-60-erb-lint-ci.md
> Ticket: COV-60
> Branch: jrdnbwmn/feature/cov-60-wire-erb-lint-ci

# Feature: Wire erb_lint into CI

## Problem

`.erb_lint.yml` exists at the repo root with `EnableDefaultLinters: true`, and
`erb_lint` is already bundled in `Gemfile.jumpstart`'s `development, :test`
group — but nothing ever runs it. There is no CI step, no step in
`config/ci.rb`, and no `bin/erb_lint`. A configured linter that never runs is
the worst of both worlds: it looks covered and isn't.

Found during the COV-57 DevOps audit.

## Approach

Clear the existing backlog of offenses, then wire the linter into the two
places this repo runs checks: the existing `lint` job in GitHub Actions, and
`config/ci.rb` so `bin/ci` mirrors it. No new CI job and no extra bundle
install — the `lint` job already has the bundle cached.

Invocation goes through a new `bin/erb_lint` binstub so ERB linting matches how
every other check in this repo is called (`bin/rubocop`, `bin/brakeman`,
`bin/bundler-audit`, `bin/importmap`).

## Acceptance Criteria

- `bin/erb_lint --lint-all` exits clean (0 offenses) on the branch
- The `lint` CI job fails when a deliberate ERB offense is introduced
- `bin/ci` runs the same check
- No visual regressions from the autocorrect — spot-check the kitchen sink page

## Prototype

None.

## Data Model

None — this is tooling. No models, migrations, or schema changes.

## Screens / Flows

No user-facing screens. Two developer-facing entry points:

1. **Local:** `bin/erb_lint --lint-all -f compact` (and `-a` to autocorrect).
2. **CI:** the `lint` job in `.github/workflows/ci.yml`, and `bin/ci` via
   `config/ci.rb`.

## Scope

**In:**

### 1. `bin/erb_lint` (new file)

Modeled directly on `bin/rubocop`. Pins `--config` **only** — deliberately
*not* `--lint-all`, because that would break single-file runs like
`bin/erb_lint app/views/foo.html.erb`. Callers pass `--lint-all` themselves,
which means one identical invocation string everywhere.

```ruby
#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

ARGV.unshift("--config", File.expand_path("../.erb_lint.yml", __dir__))

load Gem.bin_path("erb_lint", "erb_lint")
```

Note the exe name: the gem ships **both** `erb_lint` and `erblint`. Use
`erb_lint` — `erblint` is deprecated and emits a warning.

Must be `chmod +x`.

### 2. Clear the 44 whitespace offenses via autocorrect

Run `bin/erb_lint --lint-all -a`. Every one of the 44 is the same linter,
`SpaceInHtmlTag`. Touches 14 files:

| File | Offenses |
|---|---|
| `app/components/password_component.html.erb` | 9 |
| `app/components/radio_component.html.erb` | 6 |
| `app/components/switch_component.html.erb` | 5 |
| `app/components/checkbox_component.html.erb` | 5 |
| `app/components/dropdown_component.html.erb` | 4 |
| `app/components/breadcrumb_component.html.erb` | 3 |
| `app/components/ui_tabs_component.html.erb` | 2 |
| `app/components/ui_tabs_component/tab_component.html.erb` | 2 |
| `app/components/navbar_component.html.erb` | 2 |
| `app/components/dropdown_component/submenu_component.html.erb` | 2 |
| `app/components/navbar_component/item_component.html.erb` | 1 |
| `app/components/ui_toast_component.html.erb` | 1 |
| `app/views/application/_account_menu.html.erb` | 1 |
| `app/views/application/_dev_menu.html.erb` | 1 |

### 3. Hand-fix the 4 `RequireInputAutocomplete` offenses

The ticket originally proposed `off` for all four. Deviating on two of them:
the kitchen sink is the design-system showcase people copy-paste from, so it
should model the correct habit rather than teach people to silence the linter.

| File:line | Field | Value | Why |
|---|---|---|---|
| `app/views/dev/kitchen_sink/show.html.erb:17` | Display name | `nickname` | Exact HTML autofill token for "a short name identifying the user" — matches the field's own helper text, "Shown to collaborators" |
| `app/views/dev/kitchen_sink/show.html.erb:31` | Email | `email` | Unambiguous |
| `app/views/dev/kitchen_sink/show.html.erb:37` | Account ID | `off` | Disabled system identifier, no autofill meaning |
| `app/components/pagination_component.html.erb:34` | Jump to Page (`number_field_tag`) | `off` | Page number, no autofill meaning |

The first three are raw `<input>` tags — add an `autocomplete="..."` attribute.
The fourth is a `number_field_tag` — add `autocomplete: "off"` to its options.

### 4. `.github/workflows/ci.yml`

One line appended to the **existing** `lint` job, after `bin/rubocop -f github`:

```yaml
      - run: bin/erb_lint --lint-all -f compact
```

No new job, no extra `bundle install`, no changes to any other job.

### 5. `config/ci.rb`

One step, directly after `step "Style: Ruby"`:

```ruby
  step "Style: ERB", "bin/erb_lint --lint-all -f compact"
```

**Deferred:**

- Widening the lint glob. `--lint-all` covers `**/*.html{+*,}.erb` only, so
  `.text.erb` mailer views and `.turbo_stream.erb` files stay unlinted.
  Accepted as-is.
- Changing which linters are enabled. `EnableDefaultLinters: true` gives 14
  linters; the noisy opt-in ones (`HardCodedString`, `SpaceIndentation`,
  `Rubocop`) stay off. No change to `.erb_lint.yml` at all.
- Excluding `lib/jumpstart/**`. Decided against — see More Info.
- A pre-commit hook. This repo has no lefthook/pre-commit setup; not adding one.

## Open Questions

None.

## More Info

### Linting the vendored Jumpstart engine — decided: include it

`--lint-all` matches **301 files**, of which **178 live under
`lib/jumpstart/`** (the vendored Jumpstart Pro engine). They are clean today,
so including them costs nothing now.

The argument for excluding was future-facing: a JSP upgrade could import
upstream ERB offenses, red-CI on code we didn't write, and autocorrecting them
would create merge conflicts on every subsequent upgrade. Decision was to
**include anyway** and deal with that if and when it happens, rather than
carve out an exclude for a hypothetical. `.erb_lint.yml` therefore needs no
edit — its only exclude stays `vendor/bundle/**/*`.

### Why the autocorrect is low-risk

All 44 whitespace offenses come from a single linter, `SpaceInHtmlTag`, which
only adjusts whitespace *between attributes inside* `<...>`. It never touches
text nodes. Rendered output is byte-identical modulo whitespace browsers
discard. The kitchen-sink spot-check in the acceptance criteria is cheap
insurance, not a real risk — do it, but don't expect to find anything.

### Commit structure

This lands ~19 changed files, over the usual ~7-file limit, but 14 of those are
pure mechanical autocorrect. Split into two commits so review stays tractable:

1. **Commit 1** — `bin/erb_lint --lint-all -a` output only. Whitespace,
   zero hand-editing. Skimmable.
2. **Commit 2** — the 4 autocomplete fixes + `bin/erb_lint` + `ci.yml` +
   `config/ci.rb`. This is the one that gets reviewed.

Note that commit 1 depends on `bin/erb_lint` existing, or must be produced with
`bundle exec erb_lint --lint-all -a --config .erb_lint.yml`. Either ordering is
fine; simplest is to create the binstub first and amend it into commit 2.

### No test file

The behavior change here *is* CI config; its test is the CI run. Do **not**
write a test file for this. Verification is:

1. `bin/erb_lint --lint-all` exits 0 on the branch.
2. Introduce a deliberate offense (e.g. an extra space inside a tag in any
   `.html.erb`), confirm `bin/erb_lint --lint-all` exits non-zero, revert.
3. `bin/rails test` and `bin/rails test:system` still pass after the
   autocorrect.
4. Spot-check `/dev/kitchen_sink` renders correctly.
5. The PR's own `lint` job going green proves the step is wired.

Pushing a throwaway red commit to watch GitHub Actions fail is optional, not
required.

### Known noise: the `parser` gem warning

erb_lint 0.9.0 emits this on stderr every run:

```
warning: parser/current is loading parser/ruby33, which recognizes 3.3.x-compliant
syntax, but you are running 4.0.5.
```

It's a warning, not a failure — exit code is unaffected, and CI will be green.
It does mean the `ParserErrors` linter parses ERB against a Ruby 3.3 grammar,
so genuinely-new Ruby 4.0 syntax inside an ERB tag could false-positive
someday. Nothing trips it today. Don't try to "fix" this; it's upstream.

### No `github` formatter

Unlike RuboCop, erb_lint has no `github` formatter — available formats are
`compact, gitlab, json, junit, multiline`. So there will be **no inline PR
annotations** for ERB offenses regardless of what we pass. `-f compact` is
chosen because it prints one `file:line:col: [Linter] message` per offense,
which reads far better in an Actions log than the default `multiline`. The
same flag is used locally and in CI so the invocation string is identical
in all three places.

### Environment reminder

Per AGENTS.md, prepend mise's shims before running anything:
`export PATH="$HOME/.local/share/mise/shims:$PATH"`. Confirm `ruby -v` reports
4.0.5 before trusting output.
