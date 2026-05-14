---
name: audit-wiki
description: Check the Mihai16/symphony GitHub wiki for staleness against the current code, spec, and conventions. Use at the start of non-trivial work in a wiki-documented area, opportunistically when a session is light, and after a PR merges that should have updated the wiki but didn't. Pairs with manage-wiki (apply the fix) and manage-issue (file follow-ups for non-trivial drift).
---

# Audit the Symphony Wiki

The wiki drifts. This skill is the periodic counter-pressure: read a wiki page, cross-check it
against the current source of truth, and either fix small mismatches in line or file an issue for
larger ones.

## When to invoke

- **Pre-work check** — before starting non-trivial work in an area the wiki documents (operator
  guides for the changing feature, ADRs touching the same module). Catch stale claims before
  they confuse review.
- **Opportunistic** — if a session is light and the user has not given other work, run a single
  page through the audit. Don't audit the entire wiki in one shot — it doesn't scale and the
  context cost is too high.
- **Post-merge** — when a PR merges that *should* have updated the wiki but didn't, audit the
  pages it affects and either patch them or file `wiki-drift` issues.

Do **not** invoke as a routine "check everything" sweep. The audit is scoped, not exhaustive.

## Procedure

### Step 1 — Pick scope

Choose one of:

- A single wiki page (the most common scope).
- All pages tagged or linked from a single ADR or convention.
- All pages referencing a specific module path (e.g. anything mentioning
  `lib/symphony_elixir/codex/app_server.ex`).

Tell the user the scope you picked before starting; let them retarget if needed.

### Step 2 — Read the page and identify claims

Clone or pull the wiki (see `manage-wiki` Step 1). Read the target page and extract concrete
claims that could go stale:

- File paths and module names.
- Schema field names, defaults, and validation rules.
- CLI commands and flags.
- Section references into `SPEC.md`.
- Behaviour descriptions ("the orchestrator skips dispatch when …").
- Example snippets and code blocks.

Ignore claims that are inherently durable (general motivation, problem statements, ADR
rationale).

### Step 3 — Cross-check each claim

For each claim, find the current source of truth:

- File paths → check the path exists and the named symbol lives there.
- Schema fields → `grep` the schema module (e.g.
  `elixir/lib/symphony_elixir/config/schema.ex`) for the field name and default.
- Spec references → open `SPEC.md` and verify the section number/title matches.
- CLI commands → check `elixir/Makefile`, `mix.exs`, or the relevant CLI entry point.
- Behaviour → read the implementing module; if behaviour described is no longer present,
  flag.
- Example snippets → run them mentally against the current schema; if they would no longer
  parse or compile, flag.

Use `Bash` with `grep -n` for symbol lookups; use `Read` for verifying section content.

### Step 4 — Categorize findings

For each mismatch, classify:

- **Trivial** — typo, dead link, renamed file (one-line fix, no semantics changed).
- **Cosmetic** — wording out of date but meaning preserved.
- **Structural** — schema/behaviour described no longer matches code; readers will be misled.
- **Critical** — operator following the page will hit an error or take a destructive action.

### Step 5 — Act

- **Trivial / cosmetic** — fix in line via `manage-wiki`. One commit covering all small fixes is
  fine; include "Audit fixes for <page>" in the commit message.
- **Structural** — file a `wiki-drift` issue via `manage-issue` with a clear description of the
  mismatch and a pointer to the source of truth. Patching structural drift inside an audit pass
  invites scope creep; track it instead and let it be planned.
- **Critical** — file the issue *and* edit the page with a clear warning admonition at the top
  ("This page is out of date as of YYYY-MM-DD; see issue #N"), then push immediately. Do not
  leave the misleading content live without warning.

### Step 6 — Report

Tell the user:

- Pages audited.
- Counts by category (e.g. "3 trivial fixed in line, 1 structural filed as #N, 0 critical").
- Links to any issues filed and the wiki commit URL.

## Anti-patterns

- **Auditing exhaustively.** This skill is scoped; one to a few pages per pass.
- **Patching structural drift inline.** It bloats the audit commit and merges scope. File the
  issue, fix it deliberately.
- **Trusting your memory of the spec.** Re-read `SPEC.md` and the code; do not validate from
  recall.
- **Silent fixes.** Always report what changed so the user can scan for unintended edits.

## Related skills and references

- `.claude/memory/workflow.md` — wiki scope and the freshness rule.
- `.claude/skills/manage-wiki/` — applies fixes once drift is found.
- `.claude/skills/manage-issue/` — files `wiki-drift` issues for structural problems.
