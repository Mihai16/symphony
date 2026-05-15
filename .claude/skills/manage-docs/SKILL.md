---
name: manage-docs
description: Add, edit, or preview pages on the Symphony developer docs site under `docs-site/` (Docusaurus + MDX + Mermaid). Use whenever a change introduces or modifies developer-facing architecture, design, or ADR content. Pairs with manage-wiki (operator how-tos go to the wiki, not here) and manage-issue (track the change).
---

# Manage the Symphony Developer Docs Site

The developer docs live in `docs-site/`, a Docusaurus 3 project. Pages are MDX with Mermaid
support. The deployed site is at <https://mihai16.github.io/symphony/> and rebuilds on every push
to `main` via `.github/workflows/docs.yml`.

Scope of this site is set in `.claude/memory/workflow.md`:

- **In:** architecture pages, ADRs, design notes, subsystem deep-dives, glossaries aimed at
  contributors.
- **Out:** the spec (lives in `SPEC.md`), operator how-tos (live on the GitHub wiki), in-flight
  proposals (live in `proposals/`).

When in doubt: if a contributor needs it to **change** the system, it goes here. If an operator
needs it to **run** the system, it goes on the wiki.

## When to invoke

- A PR is introducing or modifying a developer-facing architecture / design / ADR document.
- A new subsystem is shipping and deserves a docs page.
- A non-trivial feature is starting — write its feature doc here *before* filing the issue or
  starting code. This is the doc-driven default; see "Feature docs" below and the
  "Feature Doc-Driven Development" section in `.claude/memory/workflow.md`.
- An existing page is stale relative to code or spec.
- The user asks "where do these docs live" / "write the architecture for X" / "document Y for
  contributors".

Do **not** invoke for:

- `SPEC.md` edits (the spec edits itself, in place at repo root).
- Operator how-tos (use `manage-wiki` instead).
- The original *proposal* — that still lives in `proposals/<slug>.md`. The per-feature/per-phase
  *implementation docs* split out from an accepted proposal live here, not in `proposals/`.

## Feature docs

For any non-trivial feature, the feature doc on this site is the source of truth for scope,
acceptance criteria, dependencies, and risks. Issues and PRs link to it; they do not duplicate
it. Multi-phase features get one MDX file per phase, all under
`docs-site/docs/architecture/<feature>/<phase-slug>.mdx`, with a parent overview page at
`docs-site/docs/architecture/<feature>.mdx` that lists the phases.

Required structure of a feature/phase doc (in addition to standard front matter):

1. H1 matching `title`.
2. Header blockquote: `> Tracking issue: [#N](...)` + plan/proposal / prior-phase backlinks.
3. Sections in this order: `Summary`, `Goals`, `Non-Goals`, `Files Touched`,
   `Detailed Change Set`, `Acceptance Criteria` (checkbox list), `Test Plan` (checkbox list),
   `Dependencies`, `Risks`, `Follow-ups` (optional).

Open the tracking issue *after* the doc exists, with `Tracking doc: <docs-site URL>` at the
bottom of the issue body. Cross-link the issue number back into the doc's header. The chain of
dependencies between phases (e.g. Phase 2 depends on #19) is recorded in both directions so a
reader landing on either side sees the whole picture.

When the feature lands, keep the doc — it stops being "planned" and becomes the durable
architectural record. Update it in the same PR that lands the code, never let it drift.

## Procedure

### Step 1 — Decide page location and slug

Pages live under `docs-site/docs/<area>/<slug>.mdx`. Areas today:

- `architecture/` — accepted designs, with diagrams. ADRs embedded inline.
- *(new areas are fine; create a directory and a sidebar category to match)*

**Slug rule.** Kebab-case, ≤ 5 words, no version numbers (versions go in the page body).
Examples: `pipeline-extension`, `workflow-store-reload`, `agent-runner-host-selection`.

**File extension rule.** `.mdx` by default (so JSX components, admonitions, and tabs work).
`.md` is fine for pages that are pure prose + Mermaid.

### Step 2 — Write the page

Front-matter (required):

```yaml
---
sidebar_position: <N>
title: <Page title>
description: <One-sentence summary that shows up in search snippets.>
---
```

Body conventions:

- **One H1**, matching `title`. All subsections are H2 (`##`) or deeper.
- **Diagrams use Mermaid**, fenced as ```` ```mermaid ````. Two reasons: they render on the
  deployed site, and GitHub also renders them in the raw source view — so the page is useful even
  without a build.
- **Admonitions** (`:::note`, `:::caution`, `:::tip`) for callouts. Don't overuse — one or two
  per page max.
- **Code blocks** specify the language. `elixir`, `yaml`, `bash`, `json` are pre-registered in
  the Docusaurus config.
- **Link to source code** with `https://github.com/Mihai16/symphony/blob/main/<path>` rather
  than relative `../../elixir/...` paths — the deployed site doesn't resolve repo-relative paths.
- **Tables** for compact reference (module maps, decision matrices). Markdown pipe tables are
  fine.

Diagrams that paid off elsewhere in this site:

- `flowchart TD` / `flowchart LR` for module / data-flow.
- `sequenceDiagram` for lifecycles ("what happens during a worker run").
- `stateDiagram-v2` for issue / agent state machines.

### Step 3 — Wire it into the sidebar

Edit `docs-site/sidebars.js`. Add the slug to the right category in `mainSidebar`:

```js
{
  type: 'category',
  label: 'Architecture',
  collapsed: false,
  items: [
    'architecture/pipeline-extension',
    'architecture/<new-slug>',         // new page
  ],
},
```

The string is the slug *without* the `.mdx` extension, relative to `docs-site/docs/`.

If the page belongs to a brand-new category, add a new `{ type: 'category', label, items }` block
in the same shape.

### Step 4 — Preview locally

```bash
cd docs-site
npm install              # first time only
npm run start
```

Serves on <http://localhost:3000/symphony/> with hot reload. Check:

- the page appears in the sidebar where you expect,
- Mermaid diagrams render (if they don't, the dev console shows the parse error),
- internal links resolve,
- `npm run build` succeeds (catches broken-link warnings that `start` is more forgiving about).

### Step 5 — Cross-references

- If a `proposals/<slug>.md` is now accepted and represented by this page, link to the proposal
  in the page header so the historical context is one click away. Don't delete the proposal —
  it's the record of how the decision was reached.
- If the page replaces a section of `SPEC.md`, **don't**. The spec stays source-of-truth; the
  docs page links to it.
- If the page documents behavior that operators also care about, drop a sentence on the
  corresponding wiki page pointing at this URL. Use `manage-wiki` for the wiki edit.

### Step 6 — Memory and skills

If the convention you're documenting is new (e.g. "all new modules get a one-page entry under
`docs-site/docs/architecture/`"), add it to `.claude/memory/workflow.md` so future sessions follow
the rule by default. Use `update-config` if there's an associated permission or hook to register.

## What NOT to do

- **Do not duplicate `SPEC.md`** here. Link to it. The spec is the contract; this site is
  explanation.
- **Do not embed screenshots of code** — paste the code in a fenced block with the right
  language tag.
- **Do not write a multi-page tutorial** unless you commit to maintaining it. Reference the code
  + a Mermaid diagram is usually enough.
- **Do not depend on the deployed URL** in code or other docs. Link to the source file on
  GitHub; the deployed site is for readers, the source is the canonical artifact.

## Quick checklist (paste in PR description)

```
- [ ] Page lives under `docs-site/docs/<area>/<slug>.mdx`
- [ ] Front-matter present (sidebar_position, title, description)
- [ ] At least one Mermaid diagram if the page describes flow or structure
- [ ] Sidebar entry added in `docs-site/sidebars.js`
- [ ] `npm run build` succeeds locally
- [ ] Relevant proposal / spec / wiki page linked
```
