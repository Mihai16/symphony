---
name: blocker-protocol
description: Handle a blocker — something that prevents the current unit of work from completing correctly this session. Use when CI/triage can't determine the real problem, an environment/credential gap blocks the fix, two fix attempts hit the same wall, or a mid-work gap (afterthought) is discovered. File the blocker as its own issue, link it (native blocked_by → sub-issue), stop, and hand back for mandatory human review. Pairs with manage-issue and ci-failure-triage.
---

# Blocker Protocol

Operationalizes `.claude/memory/blocker-protocol.md`: recognize a blocker,
file it as its own tracked issue, link it structurally, stop speculative work,
and require human review before the filed issue is started. The CI-log case is
the `ci-failure-triage` specialization of this.

## When to invoke

- Triage can't find the real problem (logs unreadable, repro impossible here).
- An environment/credential/dependency gap blocks the correct fix.
- Two fix attempts have hit the **same** wall — stop before the third.
- A PR check fails for a reason outside the change's scope.
- A mid-work gap surfaces that the originating issue missed (afterthought).

## Procedure

### Step 1 — File the blocker as its own issue

Use `manage-issue` conventions. Body must state: root cause (the real wall,
not the symptom), what is blocked (issue/PR), what was tried (so it isn't
repeated), what a fix needs (env change, credential, decision).

### Step 2 — Link it (priority order; do as many as available)

1. **Native `blocked_by` (primary).**

   ```
   gh api --method POST \
     repos/Mihai16/symphony/issues/<blocked#>/dependencies/blocked_by \
     -F issue_id=<blocking-issue DATABASE id>
   gh api repos/Mihai16/symphony/issues/<blocked#>/dependencies/blocked_by   # verify
   ```

   `-F` = typed integer (`-f` → `422`). `issue_id` is the **database id**, not
   the number (fetch via `mcp__github__issue_read`). A `403` on POST with a
   `200` on the same `GET` is a PAT-scope gap (report it), *not* the #29
   network-allowlist failure.

2. **Sub-issue (complementary).** `mcp__github__sub_issue_write`,
   `method: add`, `issue_number` = blocked **issue** (PRs can't be parents),
   `sub_issue_id` = blocker's **database id**.

These are the only two mechanisms. Do **not** add `⛔`-style "blocked by"
comments or "do not merge" lines to issues or PR descriptions.

### Step 3 — Post a handoff document

Comment on the blocker issue with enough state for a fresh session to resume
without re-deriving context: what was tried, exact commands + output, the
precise wall, the smallest next step. Issue comment, not a repo file.

### Step 4 — Stop

- No speculative fix pushes on the blocked item.
- `unsubscribe_pr_activity` for the blocked PR so identical CI failures don't
  retrigger blind cycles.
- Hand the blocker issue (with links) back to the user.

### Step 5 — Do not self-start

The filed issue needs **human review before work starts**. Do not begin
implementing an issue you just filed.

## Afterthought sub-case

A gap the originating issue missed, found mid-work, is **not** a blocker (the
current work continues). File it and link it to the current issue via the
structural mechanisms above (native dependency and/or sub-issue). Resolve
before the current PR merges — never silently fold it in or drop it.

## Anti-patterns

- Third (and fourth) blind fix push at the same wall instead of filing.
- Treating the blocker as a comment instead of its own issue.
- Using the issue *number* where the API needs the *database id*.
- Self-starting a freshly filed issue without human review.
- Leaving PR activity subscribed so the same CI failure loops.
- Folding an afterthought silently into the current PR.
- Adding `⛔`/"do not merge" emulation text instead of the structural links.

## References

- `.claude/memory/blocker-protocol.md` — the durable convention.
- `.claude/memory/ci-triage.md` / `.claude/skills/ci-failure-triage/` — CI case.
- `.claude/memory/workflow.md` — Issue Lifecycle / Blockers.
- `.claude/skills/manage-issue/` — issue create/update/close.
- Issue #30; motivating incident PR #28 / issue #19 (blocker #31).
