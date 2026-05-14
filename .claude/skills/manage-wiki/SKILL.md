---
name: manage-wiki
description: Add or update pages on the Mihai16/symphony GitHub wiki. Use whenever a change lands (or is about to land) that affects user-facing behavior, operator procedure, or shared conventions documented in the wiki. Also use to create the initial wiki entry for a new convention or operator how-to. Pairs with audit-wiki (verify freshness) and manage-issue (track the change).
---

# Manage the Symphony Wiki

The GitHub wiki at `git@github.com:Mihai16/symphony.wiki.git` is a separate git repository.
Updates land via `git push` to the wiki repo, **not** through the GitHub API and **not** through
the `mcp__github__*` tools, which target the main code repo only.

Scope of the wiki is set in `.claude/memory/workflow.md`:

- **In:** operator how-tos, accepted ADRs, human-readable conventions, glossary.
- **Out:** contract reference (lives in `SPEC.md`), schemas/examples (live with the code),
  in-flight design (lives in `proposals/`).

## When to invoke

- A PR is about to merge (or has just merged) that changes behavior, procedure, or convention
  visible to operators or contributors.
- A new convention is being established (this very change set is an example).
- A wiki page is referenced in an issue or PR comment as stale.
- After `audit-wiki` flags drift.

Do **not** invoke for internal refactors with no operator-visible effect, or for changes to
`SPEC.md` (the spec is its own source of truth — link to it from the wiki, don't mirror it).

## Procedure

### Step 1 — Locate or clone the wiki

The wiki is not part of this checkout. Clone it to a sibling working directory the first time:

```bash
# From a path outside the main repo, or under a gitignored ./wiki/
git clone git@github.com:Mihai16/symphony.wiki.git symphony-wiki
```

If a `symphony-wiki/` (or similar) checkout already exists locally, `git pull` it before editing.
If unsure where it lives, **ask the user** rather than guessing or re-cloning into the main repo.

### Step 2 — Identify the right page

Wiki pages are markdown files at the wiki repo root with names like `Home.md`,
`Operator-Guide.md`, `ADR-0001-pipeline-extension.md`.

Check `Home.md` first — it should be the table of contents. If the page you want to edit isn't
linked from `Home.md`, fix that as part of this change.

Common page categories:

- `Operator-*.md` — operator-facing how-tos.
- `ADR-NNNN-<slug>.md` — accepted architectural decisions, numbered sequentially. New ADRs get
  the next free number.
- `Convention-*.md` — durable conventions (e.g. `Convention-Branching.md`, mirroring the
  human-facing parts of `.claude/memory/workflow.md`).
- `Glossary.md` — terms.

### Step 3 — Edit

Edits should be operator-readable. Avoid implementation detail unless that detail is the topic.
Link to the corresponding code location (`elixir/lib/...`) or spec section (`SPEC.md §X.Y`)
rather than copying their contents.

For ADRs, use this skeleton:

```markdown
# ADR-NNNN: <title>

- **Status:** Accepted | Superseded by ADR-MMMM
- **Date:** YYYY-MM-DD
- **Issue:** #<n>
- **PR:** #<m>

## Context
<what problem and constraints>

## Decision
<what we chose>

## Consequences
<what changes operationally; what we accept by choosing this>

## Alternatives considered
<brief>
```

### Step 4 — Commit and push

Wiki commits use the same convention as the main repo: imperative subject, body explains the
why. Reference the originating issue/PR by URL (`https://github.com/Mihai16/symphony/issues/N`).

```bash
git -C <wiki-checkout> add <files>
git -C <wiki-checkout> commit -m "Document <topic> (issue #N)"
git -C <wiki-checkout> push origin master   # wiki default branch is usually master, not main
```

Do not amend or force-push the wiki — its history is shared with operators reading via the GitHub
UI.

### Step 5 — Cross-link

After the wiki page lands:

- If the change came from a merged PR, add a comment on the PR linking the new/updated page.
- If from an open issue, comment on the issue with the link.
- If the wiki page is the home of a recurring procedure (e.g. an ADR), link to it from
  `Home.md` and from `proposals/<the-proposal>.md` once the proposal is marked accepted.

### Step 6 — Note follow-ups

If editing surfaced unrelated drift on adjacent pages, file an issue tagged `wiki-drift` (via
`manage-issue`) rather than expanding this edit. Keep wiki commits focused.

## Anti-patterns

- **Mirroring `SPEC.md` into the wiki.** Link instead. Two sources of truth diverge.
- **Editing the wiki without an originating issue or PR.** For meaningful changes, file an issue
  so the rationale is traceable. Pure typo fixes are exempt.
- **Cloning the wiki into the main repo checkout** without gitignoring it. The wiki must not end
  up in the main repo's working tree.
- **Pushing wiki updates pre-merge** when the PR they document is still in review. Wait until the
  PR merges so the wiki doesn't claim a change that may still be reworked.

## Related skills and references

- `.claude/memory/workflow.md` — wiki scope and update rule.
- `.claude/skills/audit-wiki/` — periodic freshness check.
- `.claude/skills/manage-issue/` — file an issue for non-trivial wiki edits.
