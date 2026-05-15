# Skill & Memory Conventions (#32 umbrella)

Intentionally brief. The skill `.claude/skills/memory-issue/` operationalizes
this; user keyword **"memory issue"** (also "memory", "remember this pattern")
invokes it.

## #32 is the umbrella

[#32](https://github.com/Mihai16/symphony/issues/32) — *"Skill & memory
conventions: umbrella tracking issue"* — is the standing, always-open index for
all `.claude/` skill/memory convention work. Do not close it.

Any new skill/memory convention issue is filed normally, then **attached as a
sub-issue of #32**: `mcp__github__sub_issue_write`, `method: add`,
`issue_number: 32`, `sub_issue_id` = the child's **database id** (not its
number).

## Proactive pattern/anti-pattern capture

When a reusable pattern or anti-pattern surfaces mid-work, *proactively* open a
**quick, small** issue — a few lines, one pattern, not a treatise — and attach
it under #32. Per the #30 protocol: filed for human review; do **not**
self-start implementation.

## Memory garbage collection

When adding/changing a memory entry, first scan `.claude/memory/` for entries
that conflict with or are superseded by the new one and reconcile them (update
or delete) so memory never accumulates contradictions. Record every GC action
(what was removed/changed and why) in that same quick capture issue as the
audit trail — never silently drop prior memory.

## References

- Issues #32 (umbrella), #33 (this note), #30 (file-then-human-review).
- `.claude/skills/memory-issue/`, `.claude/skills/manage-issue/`,
  `.claude/memory/workflow.md`.
