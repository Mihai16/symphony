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
- PR title: same as the issue title, or a closely related rewording. Keep under 70 chars.
- PR body has two sections at minimum: **Summary** (1–3 bullets, the why) and **Test plan**
  (markdown checklist).
- One PR per issue. If a single issue's scope grows during work, file follow-up issues for the
  excess; don't expand the PR.
- PRs are created only when the user explicitly asks. Do not open PRs proactively unless the
  user's request implies it ("ship it", "open a PR", etc.).

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

## Wiki Documentation

The GitHub wiki is the canonical home for:

- Operator-facing how-tos ("How to swap pipelines without restart", "How to add an SSH worker").
- Architectural decision records summarizing accepted proposals.
- Conventions visible to humans interacting with the repo (this file's content,
  reproduced in operator-friendly form).
- Glossary of project-specific terms.

The wiki is **not** the home for:

- API/contract reference — that lives in `SPEC.md`.
- Source-of-truth schemas or examples — those live next to the code in `elixir/`.
- In-flight design discussion — that lives in `proposals/` until accepted.

**Rule:** if a PR changes user-facing behavior, operator procedure, or shared convention, it
includes a wiki update in the same change set when the wiki page exists locally, or a follow-up
wiki update committed within one working day if the wiki is checked out separately. Code-only
internal refactors do not need wiki updates. See `.claude/skills/manage-wiki/`.

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

When asked to produce architecture documents (e.g. `ARCHITECTURE.md`), design notes, or any
artifact that requires *making decisions* on top of an existing proposal or plan, you OWN the
decisions. Read the relevant inputs (proposal, plan, code) and commit to specific choices with
rationale — do not return a menu of options without picking one.

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
