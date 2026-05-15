---
name: memory-issue
description: 'Capture a reusable pattern/anti-pattern as a quick small GitHub issue under the #32 skill/memory umbrella, and garbage-collect contradictory memory. Invoke on the user keyword "memory issue" (and close variants: "memory", "remember this pattern", "capture this pattern"), or proactively when a reusable pattern/anti-pattern surfaces mid-work. Pairs with manage-issue and .claude/memory/skill-memory-conventions.md.'
---

# Memory Issue (#32 umbrella + proactive capture + memory GC)

Operationalizes `.claude/memory/skill-memory-conventions.md`. Triggered by the
user keyword **"memory issue"** (also "memory", "remember this pattern",
"capture this pattern"), or proactively when a durable pattern/anti-pattern is
identified mid-work.

## When to invoke

- User says "memory issue", "remember this pattern", "capture this".
- You identify a reusable pattern or anti-pattern worth keeping for future
  sessions.
- You are about to add/change a `.claude/memory/` entry (run the GC step).

## Procedure

### Step 1 — File a quick, small capture issue

Open one issue describing **just that one pattern**. Hard constraint: a few
lines, one pattern each — not a treatise. Use `manage-issue` conventions.

Per the #30 protocol: the issue is filed **for human review**. Do **not**
self-start implementation.

### Step 2 — Attach it under the #32 umbrella

`mcp__github__sub_issue_write`:

- `method: add`
- `issue_number: 32`
- `sub_issue_id` = the new issue's **database id** (not its number — fetch via
  `mcp__github__issue_read` if needed).

### Step 3 — Memory garbage collection

Before adding/changing any `.claude/memory/` entry, scan `.claude/memory/` for
entries that conflict with or are superseded by the new one. Reconcile them
(update or delete) so memory never holds contradictions.

Record every GC action — what was removed/changed and why — as the audit trail
**in that same capture issue**. Never silently drop prior memory.

## Anti-patterns

- Growing one big memory doc instead of many small children under #32.
- Self-starting a filed capture issue without human review (violates #30).
- Editing memory and leaving a now-contradictory older entry in place.
- Using the issue's *number* where the sub-issue API needs its *database id*.

## References

- `.claude/memory/skill-memory-conventions.md` — the durable convention.
- Issues #32 (umbrella), #33 (this skill), #30 (file-then-human-review).
- `.claude/skills/manage-issue/`, `.claude/memory/workflow.md`.
