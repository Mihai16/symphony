# Symphony Workflow Conventions

Durable conventions for Claude sessions working in this repository. These are the rules of the
road — read them before starting non-trivial work. Skills under `.claude/skills/` implement the
procedures these conventions describe.

## Repository

- Primary repo: `Mihai16/symphony` (GitHub).
- Default branch: `main`.
- Wiki: `git@github.com:Mihai16/symphony.wiki.git` (separate git repo; cloneable with the same
  GitHub auth as the main repo).
- Reference implementation lives under `elixir/`. Specification is `SPEC.md` at the repo root.
  Proposals live under `proposals/`.

## Unit of Work

**Every non-trivial change is tied to a GitHub issue.** If no issue exists for the work, file one
*first* — see `.claude/skills/manage-issue/`. The issue is the durable home for context,
discussion, and links to the resulting PR.

Trivial changes that do not need an issue:

- Typo fixes in code comments or non-spec markdown.
- Reverting a just-pushed commit on a branch with no open PR.
- Updating `.claude/` memory or skills in response to direct user instruction (the conversation
  itself is the durable context).

When in doubt, file the issue. The cost is seconds; the benefit is traceability.

## Branch Naming

One branch per issue. Name format:

```
issue-<number>-<short-kebab-slug>
```

- `<number>` is the GitHub issue number.
- `<short-kebab-slug>` is 2–5 words from the issue title, lowercase, hyphen-separated.
- Examples: `issue-2-claude-workflow-skills`, `issue-17-fix-stall-timeout`,
  `issue-42-pipeline-extension-phase-1`.

Branches are created from `main` unless explicitly stacking on another in-flight branch (e.g.
"phase 2 builds on the still-open phase 1 PR"). When stacking, prefix the slug with the parent
issue number so the dependency is visible: `issue-43-on-42-pipeline-runner-extraction`.

Exceptions:

- **Harness-supplied branches** (e.g. `claude/proposal-implementation-plan-XXXX`) are honoured as
  given. The harness owns those names. The first commit on such a branch SHOULD still reference an
  issue if one applies.
- **Hotfixes** to `main` may use `hotfix/<short-slug>` without an issue if the fix is being filed
  *as* the issue (i.e. the PR description is the bug report). Open the issue immediately after
  pushing.

See `.claude/skills/start-issue-branch/` for the full procedure.

## Pull Requests

- **Always close the issue from the PR when possible.** This is a strong user preference. The PR
  body MUST open with `Closes #<issue-number>` (or `Fixes #N` / `Resolves #N` — all accepted by
  GitHub) so merging the PR auto-closes the issue without a separate manual step. If a single PR
  resolves multiple issues, list each: `Closes #N, Closes #M`. The only time this is skipped is
  when no issue exists (e.g. the trivial-change carve-out above, or a hotfix being filed as its
  own issue). In every other case: tie the PR to its issue with a closing keyword.
- **⚠️ Auto-close is repo-wide, not keyword-gated.** This repo's GitHub configuration closes
  **every** issue referenced as `#N` anywhere in a merged PR body (and in commit messages that
  land on `main`) — a `Closes`/`Fixes`/`Resolves` keyword is *not* required to trigger the close.
  Consequence: a PR body must mention **only** the issue numbers it actually intends to close.
  Never write a bare `#N` for a context/related/parent issue. In particular, the standing
  always-open umbrella (currently issue 32) and other tracking issues must be referred to
  *without* the `#` linkifier (write "umbrella issue 32", "issue 30") so the merge does not
  force-close them. This applies to commit messages too. See `.claude/skills/create-pr/`.
- PR title: same as the issue title, or a closely related rewording. Keep under 70 chars.
- PR body must follow `.github/pull_request_template.md` — five `####` sections (Context, TL;DR,
  Summary, Alternatives, Test Plan), in that order, no `<!--` leftovers, bullets in Summary,
  checkboxes in Test Plan. `pr-description-lint` enforces this and fails the PR otherwise.
- One PR per issue. If a single issue's scope grows during work, file follow-up issues for the
  excess; don't expand the PR.
- PRs are created only when the user explicitly asks. Do not open PRs proactively unless the
  user's request implies it ("ship it", "open a PR", etc.).

See `.claude/skills/create-pr/` for the full procedure (template rules, lint checks, body
skeleton).

## Issue Lifecycle

| State        | Trigger                                                        |
|--------------|----------------------------------------------------------------|
| **open**     | Filed via `gh`/MCP `issue_write` with method=create.           |
| **updated**  | Body or labels change to reflect new scope/progress. Comments  |
|              | are preferred for narration; body edits are for scope changes. |
| **closed**   | PR that `Closes #N` is merged, or work is explicitly declined  |
|              | (close with `state_reason: not_planned`).                      |

Skills `manage-issue` handles create/update/close. Always check for an existing issue before
filing — searching by title keywords prevents duplicates.

## Documentation — the four homes

Symphony has four documentation surfaces. Mixing them up is the most common source of drift.
Pick the right one *before* writing.

| Surface                     | Audience               | Lives in                          | Owned by skill        |
|-----------------------------|------------------------|-----------------------------------|-----------------------|
| `SPEC.md` (repo root)       | Spec readers, conformance implementers | repo                       | (none — edit directly) |
| Developer docs site         | Contributors / architects | `docs-site/` (Docusaurus + MDX + Mermaid; deployed to GitHub Pages) | `manage-docs`         |
| GitHub wiki                 | Operators              | `git@github.com:Mihai16/symphony.wiki.git` (separate repo) | `manage-wiki` / `audit-wiki` |
| `proposals/`                | Anyone, in-flight      | `proposals/<slug>.md` in repo     | (none — edit directly) |

**What goes where (one-line rules):**

- The **spec** is the contract. If conformance depends on it, it goes in `SPEC.md`. Nothing else
  duplicates the spec — pages link to it.
- The **docs site** is *contributor explanation*: architecture pages, ADRs, design notes,
  subsystem deep-dives. Files are `.mdx` (or `.md`) with Mermaid for diagrams. GitHub renders the
  source; the deployed site adds sidebar + search. New architecture decisions land here.
- The **wiki** is *operator how-to*: "how to swap pipelines", "how to add an SSH worker", glossary
  of operational terms. Not for contributor-facing internals.
- **`proposals/`** is *in-flight design*: drafts that have not been accepted. When a proposal is
  accepted, the *implementation* may land first; the durable explanation goes to the docs site
  (architecture page), and the proposal stays in `proposals/` as historical record.

**Architectural decision records** belong on the docs site under `docs-site/docs/architecture/`,
embedded inline in the architecture page they belong to (one heading per ADR), NOT on the wiki —
this is a change from the earlier convention. Operators rarely need ADRs; contributors always do.

**Rule:** if a PR changes user-facing behavior, operator procedure, or shared convention, it
includes a wiki update in the same change set when the wiki page exists locally, or a follow-up
wiki update committed within one working day if the wiki is checked out separately. If a PR
changes contributor-facing architecture or design, it includes a `docs-site/` page update in the
*same* commit (the docs site is in-repo; there is no excuse for drift). Code-only internal
refactors with no architectural shift do not need either. See `.claude/skills/manage-docs/` and
`.claude/skills/manage-wiki/`.

## Feature Doc-Driven Development

Symphony works doc-first for non-trivial features. The feature doc is the *source of truth* for
scope, acceptance criteria, dependencies, and risks — written before the code, updated as it
lands, kept after it ships. Issues and PRs are pointers to the doc; they do not duplicate it.

**When this applies:** any feature larger than a single-PR change. Multi-phase implementations
split out from a proposal, new subsystems, anything where "what is in scope?" deserves more than
the issue body. Typo fixes, small bug fixes, and one-shot refactors do not need a feature doc.

**Where the doc lives:** `docs-site/docs/architecture/<feature>/<slug>.mdx`. One file per
feature (or per phase, when a feature is multi-phase). Sibling phases share a parent directory and
appear as a nested category under the parent architecture page in `sidebars.js`. The parent page
gets an "Implementation Phases" table linking to each child with its tracking issue.

**Required front matter:**

```yaml
---
sidebar_position: <N>
title: <Phase N — short title, or feature name>
description: <one sentence, ≤ 160 chars>
---
```

**Required header block** (immediately after the H1):

```markdown
> Tracking issue: [#<n>](https://github.com/Mihai16/symphony/issues/<n>)
> Split from the [<plan>](https://github.com/Mihai16/symphony/blob/main/proposals/<plan>.md) ...
> Depends on [<prior phase>](./<prior-phase>) ([#<m>](https://github.com/Mihai16/symphony/issues/<m>)).
```

**Required sections** (in this order, headings as shown):

- `## Summary` — 2-3 sentences.
- `## Goals` / `## Non-Goals` — explicit in/out scope.
- `## Files Touched` — bullets with exact paths and line refs where applicable.
- `## Detailed Change Set` — H3 per area of the codebase.
- `## Acceptance Criteria` — checkbox list, sourced from plan/proposal where one exists.
- `## Test Plan` — checkbox list.
- `## Dependencies` — explicit prior-phase / prior-issue links.
- `## Risks` — what could break, with mitigations.
- `## Follow-ups` — sibling phases or downstream work (optional).

**Order of operations when starting a new feature:**

1. Write the feature doc(s) as MDX under `docs-site/docs/architecture/<feature>/`.
2. Add the doc(s) to `docs-site/sidebars.js`.
3. File the tracking issue with a `Tracking doc:` link at the bottom pointing at the doc.
4. Cross-link the issue number into the doc's header block.
5. Start the branch (`issue-<n>-<slug>`) and the implementation. Update the doc as scope clarifies.

The proposals under `proposals/` remain *strategy docs* (the master plan that spawned the feature
docs) and *historical record* of accepted proposals. They are NOT where per-feature scope/AC live
now that the docs site is the source of truth. Do not duplicate phase content between
`proposals/` and `docs-site/`.

**MDX gotchas** (the build will fail otherwise):

- Bare angle brackets (`<name>`, `<kind>`) outside code spans are parsed as JSX. Wrap in backticks
  or use `&lt;` / `&gt;`.
- Inside Mermaid blocks, always use `&lt;` / `&gt;` (see issue #12).
- Curly braces outside code blocks become JSX expressions.

See `.claude/skills/manage-docs/` for the operational procedure for editing the docs site.

## Post-Push CI Check

After pushing a branch or merging a PR, **check the resulting workflow runs before reporting
"done"** — silence from CI is not success. This applies in particular to pushes that land on
`main` (no PR for me to subscribe to via `subscribe_pr_activity`), and to workflows that only
trigger on `main` such as `Deploy docs site` (`.github/workflows/docs.yml`).

Procedure: after a push or merge, fetch the latest commit on the affected branch via
`mcp__github__get_commit` (or `mcp__github__pull_request_read` with `method=get_check_runs` for
PR-bound work), wait briefly for runs to register, and confirm conclusion is `success` for every
check that fires. If any check fails, investigate before handing back — don't make the user notice
the red dot.

## Wiki Freshness

The wiki drifts. To counter this, run an audit:

- At the start of any non-trivial work that touches a wiki-documented area (check the relevant
  pages first; flag mismatches in the issue before coding).
- Opportunistically — if a session is light, run `audit-wiki` over one section.
- After merging a PR that should have updated the wiki but didn't (open a follow-up issue tagged
  `wiki-drift`).

See `.claude/skills/audit-wiki/` for the audit procedure.

## Commits

- Imperative subject line, ≤ 72 chars: "Add pipeline schema resolver", not "Added" or "Adds".
- Body explains the *why* when it isn't obvious from the diff.
- Co-authored / generated-by trailers are added by the harness; do not author them manually.

## Architecture Work

When asked to produce architecture documents, design notes, or any artifact that requires
*making decisions* on top of an existing proposal or plan, you OWN the decisions. Read the
relevant inputs (proposal, plan, code) and commit to specific choices with rationale — do not
return a menu of options without picking one.

Architecture pages live under `docs-site/docs/architecture/<slug>.mdx` (see `manage-docs`).
ADRs are embedded inline in the architecture page they belong to, one H3/H4 heading per ADR.
The repo-root `ARCHITECTURE.md` is now a stub redirect to the docs site; new architecture
content does **not** go there.

If the task is too hard to do alone (large unfamiliar codebase, deep cross-module trade-offs,
multiple architectural styles in tension, or a decision that hinges on code you haven't
internalised), **summon a specialised subagent** rather than guessing. Useful subagent types for
architecture work:

- `Explore` for "where is X / who reads Y / which files implement Z" lookups that would otherwise
  fill the main context with raw greps.
- `Plan` for an independent second pass over the implementation strategy when the choice between
  two architectures is genuinely close and you want a sanity check.
- `general-purpose` for multi-step research that combines code reading, doc reading, and synthesis.

Don't delegate the *decision*. Delegate the *evidence-gathering* that lets you decide. The final
ADR-style commitments in the document are yours.

## When These Conventions Conflict With User Instructions

User instructions win. If a user says "don't bother with an issue, just push the fix", follow
that. The conventions exist to make the default path safe and traceable, not to override explicit
direction.
