---
name: manage-issue
description: Create, update, or close a GitHub issue on Mihai16/symphony. Use this whenever a unit of work begins ("file an issue for X"), progress needs recording on an existing issue, or work has finished and the issue should close. Also use proactively before starting non-trivial work if no issue exists for it (per .claude/memory/workflow.md).
---

# Manage GitHub Issue

This skill keeps issue state on `Mihai16/symphony` consistent with the conventions in
`.claude/memory/workflow.md`. Issues are the durable home for context; they are not optional for
non-trivial work.

## When to invoke

- User says "file an issue for …", "track this", "open a ticket".
- You are about to start non-trivial work and no existing issue covers it. **Check first** (see
  Step 0) — do not file duplicates.
- An open issue needs a status update or scope change.
- A PR has just merged that closed an issue — verify the issue actually closed.

## Procedure

### Step 0 — Check for an existing issue

Before creating, search for existing issues with overlapping titles or topics.

- Use `mcp__github__list_issues` with `state: OPEN` and scan titles, or
- `mcp__github__search_issues` with keywords from the proposed title.

If a match exists: update it (Step 2) instead of creating a new one. Mention it to the user and
ask if you should retitle, expand, or open a sibling issue.

### Step 1 — Create

When no matching issue exists, file one with `mcp__github__issue_write` (method: `create`).

**Title** — imperative, scoped, ≤ 70 chars:

- Good: "Add pipeline schema resolver and validation"
- Bad: "Pipeline stuff" / "Fix bug"

**Body** — structure:

```
<One-paragraph problem statement: what needs to change and why.>

## Scope
- <bullet list of concrete deliverables>

## Out of scope
- <bullet list of related-but-not-this>

## Notes
- <links to related issues, PRs, docs, wiki pages>
```

If the work has obvious sub-tasks, list them under `## Scope`. If acceptance criteria are
non-obvious, add an `## Acceptance` section.

**Labels** — apply only labels that already exist on the repo (call
`mcp__github__list_issue_types` or scan recent issues to learn the label set). Do not invent
labels.

After creation, surface the issue URL to the user. The next step is usually to start a branch
(see `start-issue-branch` skill).

### Step 2 — Update

For scope/status changes, use `mcp__github__issue_write` (method: `update`).

- **Scope changes** edit the body.
- **Progress narration** uses comments via `mcp__github__add_issue_comment` — keep them concise,
  one comment per meaningful update (PR opened, blocker found, blocker cleared). Do **not**
  comment on every commit.
- **Labels** are added/removed via `update`.

Do not edit the issue body to silently delete out-of-scope items the user has already seen — add
a comment noting the change instead, then edit. Keeping the audit trail visible matters.

### Step 3 — Close

Prefer auto-close via PR: a PR body starting with `Closes #N` will close issue N when merged.

Manual close (`mcp__github__issue_write` with method=`update`, `state: closed`) is for:

- Work declined by the user → `state_reason: not_planned` with a comment explaining why.
- Duplicates → `state_reason: duplicate`, `duplicate_of: <other-issue-number>`.
- Completed work that wasn't tracked by a PR (rare) → `state_reason: completed`.

Always leave a final comment before manual close explaining the resolution.

### Step 4 — Verify

After any operation, fetch the issue with `mcp__github__issue_read` and confirm the state matches
intent. Report the URL and final state to the user.

## Anti-patterns

- **Filing an issue and immediately closing it** to "log" something. Use a wiki page instead — see
  `manage-wiki` skill.
- **Editing the title repeatedly** as scope evolves. Open a new issue and link them.
- **Inventing labels** the repo doesn't already use. Stick to the existing label vocabulary.
- **Long auto-narrating comments.** One comment per meaningful event; conversational back-and-forth
  belongs in the PR.

## Related skills and references

- `.claude/memory/workflow.md` — issue lifecycle, when an issue is required.
- `.claude/skills/start-issue-branch/` — branch creation after issue is filed.
- `.claude/skills/manage-wiki/` — wiki updates that may accompany an issue's resolution.
