# Blocker Protocol (detect → file → link → stop → human-review-first)

Durable convention for what a Claude session does when it hits a **blocker** —
anything that prevents the current unit of work from being completed correctly
*in this session*. The skill `.claude/skills/blocker-protocol/` operationalizes
this. The CI-log-retrieval case is a specialization — see
`.claude/memory/ci-triage.md`.

The failure mode this prevents: repeated blind fix attempts and burned CI
cycles instead of recognizing the blocker as its own tracked unit of work.

## Detect

A blocker can surface at any stage. Recognize it instead of improvising:

- **Triage stage** — cannot determine the real problem (e.g. CI logs
  unreadable, repro impossible in this environment).
- **Implementation stage** — a dependency is missing, an environment/credential
  gap blocks the fix, the correct change needs context this session can't get.
- **PR-creation stage** — a check fails for a reason outside the change's scope
  and can't be fixed here.

Signal that you are blocked, not stuck-but-pushing: two failed fix attempts at
the same wall is the protocol's cue, not the third.

## File

The blocker **is an issue in itself.** Create a dedicated GitHub issue (via
`manage-issue` conventions) describing:

- **Root cause** — the actual wall, not the symptom.
- **What is blocked** — the issue/PR that cannot proceed.
- **What was tried** — so the next session doesn't repeat it.
- **What a fix needs** — environment change, credential, decision, etc.

## Link (structural relationships — required, in priority order)

1. **Native "blocked by" dependency (primary — confirmed working).**

   ```
   gh api --method POST \
     repos/OWNER/REPO/issues/<blocked#>/dependencies/blocked_by \
     -F issue_id=<blocking-issue DATABASE id>
   ```

   Verify:

   ```
   gh api repos/OWNER/REPO/issues/<blocked#>/dependencies/blocked_by
   ```

   Caveats: `-F` sends a typed integer (`-f` sends a string → `422 not of type
   integer`). `issue_id` is the blocking issue's **database id**, not its
   number — the same id `sub_issue_write` uses. Requires the fine-grained PAT
   to have issues-dependencies write (granted; takes effect immediately, no
   fresh session needed). A `403` *write* with a `200` on the identical `GET`
   is an authorization gap (PAT scope), distinct from the #29 `403 →
   egress-allowlist` network failure mode.

2. **Parent/child via GitHub sub-issues (complementary).** Add the blocker as
   a **sub-issue of the blocked issue**: `mcp__github__sub_issue_write`,
   `method: add`, `issue_number` = blocked/parent **issue**, `sub_issue_id` =
   blocker's **database id** (not its number). PRs cannot be sub-issue parents
   — the parent must be the blocked issue.

These are the only two linking mechanisms. Do **not** add `⛔`-style "blocked
by" comments or "do not merge" lines to issues or PR descriptions — the
structural links above are the record; ad-hoc text emulation is not used.

## Stop

- Stop working on the blocked item. **Do not push speculative fixes.**
- Unsubscribe from the blocked PR's activity (`unsubscribe_pr_activity`) so
  identical CI failures don't retrigger blind fix cycles.
- Hand the blocker issue back to the user with its links in place.

## Mandatory human review first

A newly-filed issue (blocker or otherwise) requires **human review before any
work starts on it.** Sessions must **not** self-start an issue they just filed.
This protocol document itself was filed (#30) and reviewed before
implementation — follow the same rule for blockers you file.

## The "afterthought" sub-case

An *afterthought* is an important gap the originating issue missed, discovered
mid-work. It is **not** a blocker — it does not stop the current issue/PR. But
it must be:

- **Filed** as its own issue (don't silently fold it into the current PR).
- **Linked** to the current issue via the structural mechanisms above (native
  dependency and/or sub-issue) — not via ad-hoc comment text.
- **Resolved before the current PR merges** — tracked via the issue link, not
  dropped.

## Handoff document

A blocker issue SHOULD carry a **handoff document**: a markdown comment on the
issue capturing enough state for a fresh session to resume *without
re-deriving context* — what was tried, exact commands/output, the precise
wall, and the smallest next step. Post it as an issue comment, not a repo file.

## References

- `.claude/skills/blocker-protocol/` — the operational skill.
- `.claude/memory/ci-triage.md` — the CI-log-retrieval specialization (#29).
- `.claude/memory/workflow.md` — Issue Lifecycle / Blockers section.
- `.claude/skills/manage-issue/` — issue create/update/close conventions.
- Issue #30 (this convention); motivating incident: PR #28 / issue #19, with
  #31 filed retroactively as the blocker.
