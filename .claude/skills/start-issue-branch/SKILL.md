---
name: start-issue-branch
description: Open a branch for an existing GitHub issue on Mihai16/symphony, following the issue-<n>-<slug> convention. Use whenever a session begins work on an issue and there is not already a branch for it. Pairs with manage-issue (file the issue first) and manage-wiki (update wiki on merge).
---

# Start an Issue Branch

Opens the working branch for a GitHub issue per `.claude/memory/workflow.md`. One branch per
issue, named `issue-<number>-<short-kebab-slug>`, branched from `main` unless explicitly stacking.

## When to invoke

- User says "let's work on #N", "start the branch for that issue", "open a branch".
- You have just filed an issue (via `manage-issue`) and the user has approved starting work.
- You discover an existing issue you'll be working on and the local repo is on `main` (or on an
  unrelated branch).

Do **not** invoke when:

- The harness has supplied a branch name (e.g. `claude/...`); use that.
- You are already on the correct issue branch — verify with `git branch --show-current` first.

## Procedure

### Step 1 — Identify the issue

Confirm the issue number and title with the user, or fetch with `mcp__github__issue_read`.
If no issue exists for the work, run `manage-issue` first.

### Step 2 — Derive the slug

Take 2–5 words from the issue title. Apply:

- Lowercase everything.
- Replace spaces and punctuation with single hyphens.
- Drop filler words (`a`, `the`, `for`, `to`, `with`) unless dropping makes the slug ambiguous.
- Drop trailing/leading hyphens.
- Cap total branch name length at ~50 chars; truncate slug words rather than middle-cutting.

Examples:

| Issue title                                              | Slug                          |
|----------------------------------------------------------|-------------------------------|
| "Add pipeline schema resolver and validation"            | `pipeline-schema-resolver`    |
| "Fix stall timeout for claude-pipeline runs"             | `fix-stall-timeout`           |
| "Phase 1: Pipeline schema and spec resolver"             | `phase-1-pipeline-schema`     |
| "Add Claude skills and memory for issue/wiki/branch workflow" | `claude-workflow-skills` |

Stacked branches prefix with the parent issue: `issue-43-on-42-pipeline-runner`.

### Step 3 — Fetch and branch

Ensure `main` is current, then branch:

```bash
git fetch origin main
git checkout -b issue-<n>-<slug> origin/main
```

Confirm with `git branch --show-current`.

If the user has unpushed work on another branch, **do not switch branches without asking** —
ask first via `AskUserQuestion`.

### Step 4 — Push (optional, first commit)

Push the branch after the first commit, not before:

```bash
git push -u origin issue-<n>-<slug>
```

Empty branches on the remote are noise. Wait for the first real commit.

### Step 5 — Link the branch on the issue (optional)

If the issue will benefit from a visible branch reference, add a comment with
`mcp__github__add_issue_comment` once the branch is pushed:

> Working on branch `issue-<n>-<slug>`.

This is optional — GitHub already cross-links once a PR opens. Skip the comment for fast-moving
work.

## Edge cases

- **Issue covers multiple deliverables that need separate branches.** File sub-issues first, then
  branch each separately. Don't pack multiple deliverables into one branch.
- **Branch already exists locally.** Check whether the work was paused. If yes, switch to it; if
  no, the previous owner abandoned it — confirm with the user before continuing or recreating.
- **Branch already exists on remote.** Fetch it (`git fetch origin <branch>`), check it out
  (`git checkout <branch>`), and read the commits before adding new work. Don't force-push someone
  else's branch.
- **No `main` branch.** Verify the default branch with `mcp__github__list_branches` and use that
  instead.

## Related skills and references

- `.claude/memory/workflow.md` — naming convention specification.
- `.claude/skills/manage-issue/` — file the issue before branching when one doesn't exist.
