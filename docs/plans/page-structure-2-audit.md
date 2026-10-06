> Ticket: COV-107
> Branch: feature/cov-107-redesign-students

# Plan: Page Structure, Phase 2: Audit Signed-In Pages

Check every signed-in page against the rules in `docs/product/ux-notes.md`
and write a findings list that Phase 3 turns into fix tasks. No app code
changes in this phase.

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Set up the audit file and checklist | Master |      |
| 2    | 1     | 1          | Audit the main pages | Clone |      |
| 3    | 1     | 1          | Audit Settings: user pages | Clone |      |
| 4    | 2     | 2          | Audit Settings: family and billing pages | Clone |      |
| 5    | 2     | 2          | Prioritize findings and propose fix groups | Master |      |

## Prerequisites

- Phase 1 (`docs/plans/page-structure-1-foundations.md`) is complete.
  The audit assumes PageHeaderComponent, the date helpers, and the modal
  changes exist.
- Design: `docs/product/ux-notes.md`, sections "States and interactions"
  and "Page structure (signed-in app)". This is the rulebook.
- Prototype: None
- Output: `.context/page-structure-audit.md` (`.context/` is gitignored
  and shared within this workspace).
- To view pages: use the run skill to start the app and sign in with a
  seeded user. Check each page at **1280px** and **390px** wide.

## Tasks

### Task 1 [Master]: Set up the audit file and checklist

**In scope:**

- Create `.context/page-structure-audit.md` with:
  1. A **Checklist** section that turns every rule in ux-notes' "States
     and interactions" and "Page structure" sections into a short,
     numbered check (e.g. `H3: header holds only title, description,
     actions`). Group the checks by ux-notes heading, prefixed P
     (principles), D (depth and width), H (header), O (where things
     open), S (spacing), T (sections and tabs), F (forms), L (lists), M
     (formats), and E (states and interactions).
  2. A **Findings** section with one subsection per page area, left for
     Tasks 2–4.
  3. The finding format, one per line:
     `- [ID] <page> (<view path>:<line>) — <what breaks the rule> → <suggested fix> (size: S/M/L)`
- The page inventory: read `config/routes.rb`, `config/routes/*.rb`, and
  `app/views/application/_account_navbar.html.erb` (the Settings tabs) to
  list every signed-in page, and record the list in the file, split
  across Tasks 2–4. A starting list is below; add anything routed that's
  missing, and mark pages that aren't routed or reachable as "skip".

**Starting inventory:**

- Main (Task 2): Dashboard, Students (index, the add/edit/delete/view
  modals, and the kept picker), Subjects, Schedules, Support,
  Notifications, Announcements.
- Settings: user (Task 3): Profile (`devise/registrations/edit`),
  Password (`account/passwords/edit`), Two-factor, Connected accounts,
  API tokens (index/new/show/edit), Referrals (if routed).
- Settings: family and billing (Task 4): Family (`accounts/show`,
  `accounts/edit`), Parents (`account_users/edit`), Invitations
  (`accounts/account_invitations/new`, `edit`, and
  `account_invitations/show` for accepting), Billing (`billing/show`,
  `billing/subscriptions/edit`, cancels, pauses, resumes, upcomings,
  payment_methods/new, plan_changes), Checkout (`checkouts/show`).

**NOT in scope:**

- Auditing anything.
- Public, Devise sign-in/up, admin, and `dev/` pages.

**Build order:**

1. **Test:** none.
2. **Implement:** write the file.
3. **Verify:** every ux-notes rule maps to at least one check. Count the
   bullets in the two sections and confirm none are missing.

### Task 2 [Clone]: Audit the main pages

**Skills:** run, style-ui
**Reference:** `.context/page-structure-audit.md` (checklist + format)

**In scope:**

- For each Task 2 page in the inventory: read its view (and the
  partials and components it renders), then view it at 1280px and 390px.
  Save screenshots as `.context/audit/<page>-desktop.png` and
  `-phone.png`.
- Write findings under the "Main" subsection. Every finding cites a check
  ID. Also check empty, at-limit, and archived states where they exist
  (Students: Free family at 2 students, Premium family at its cap, a
  family with archived students, a downgraded family that must pick).
- Note known findings even if obvious (e.g. Students' add card in the
  grid, limit text in the header, the archived section, "Schedules" vs.
  the glossary's "Schedule").

**NOT in scope:**

- Fixing anything.
- Pages from Tasks 3–4.

**Build order:**

1. **Test:** none.
2. **Implement:** audit and write findings.
3. **Verify:** every inventory page in this group has either findings or
   "No findings" written next to it.

### Task 3 [Clone]: Audit Settings: user pages

**Skills:** run, style-ui
**Reference:** `.context/page-structure-audit.md`

**In scope:**

- Same method as Task 2 for the Task 3 pages, under "Settings: user".
- Pay particular attention to: sub-pages that are deeper than one level
  (e.g. API token new/show/edit as separate pages, which break D1 and
  O1: they should be modals or tabs), tables (L-rules), `h1` used as a
  section heading inside Settings (T-rules: serif only for page titles
  and major sections), and dates not using the friendly format.

**NOT in scope:**

- Fixing anything. Family and billing pages.

**Build order:**

1. **Test:** none.
2. **Implement:** audit and write findings.
3. **Verify:** every page in this group has findings or "No findings".
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 1 (Tasks 1–3), focused on whether the findings are accurate
   and cite real lines. If Tasks 2–3 ran as a parallel batch, the master
   runs it once the batch returns. It runs exactly once per checkpoint.

### Task 4 [Clone]: Audit Settings: family and billing pages

**Skills:** run, style-ui
**Reference:** `.context/page-structure-audit.md`

**In scope:**

- Same method as Task 2 for the Task 4 pages, under "Settings: family and
  billing". Use a Free family and a Premium family.
- Pay particular attention to: tables (`accounts/show`, billing charges,
  upcoming invoice), multi-step billing flows (cancel, pause, plan
  change, checkout), which ux-notes says are focused full pages *or*
  modals (note which fits each), destructive actions placement, and
  plan-limit/plan-locked messaging.

**NOT in scope:**

- Fixing anything. Changing billing behavior.

**Build order:**

1. **Test:** none.
2. **Implement:** audit and write findings.
3. **Verify:** every page in this group has findings or "No findings".

### Task 5 [Master]: Prioritize findings and propose fix groups

**In scope:**

- Add a **Fix groups** section to the top of
  `.context/page-structure-audit.md`: cluster findings into groups that
  each fit one Phase 3 task (≤4 files, one area), in priority order:
  1. Pages parents use every day (Students, Dashboard, then the rest of
     the main pages).
  2. Rule breaks that cause real confusion (depth, tables on phones,
     missing phone behavior).
  3. Visual consistency (spacing, serif, headers).
  Each group lists its finding IDs, the files it touches, and a size.
- List anything that needs a product decision rather than a fix (e.g. a
  billing flow that doesn't fit modal *or* full page) under **Questions
  for Jordan**.

**NOT in scope:**

- Writing Phase 3 tasks into the Phase 3 plan (that happens in Phase 3,
  Task 6, after user approval).

**Build order:**

1. **Test:** none.
2. **Implement:** the two new sections.
3. **Verify:** every finding ID appears in exactly one fix group or in
   Questions.
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 2 (Tasks 4–5). It runs exactly once per checkpoint. Then
   stop and show the user the Fix groups and Questions sections.

## Task Dependencies

- Task 1 comes first (it creates the file and inventory).
- Tasks 2, 3, and 4 depend on Task 1 and can run in parallel. Each writes
  only its own subsection; if run in parallel, have each return its
  findings text and let the master paste them in to avoid edit conflicts.
- Task 5 depends on Tasks 2–4.
