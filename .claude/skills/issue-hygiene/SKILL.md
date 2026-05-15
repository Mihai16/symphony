---
name: issue-hygiene
description: Audit and clean up GitHub issues on Mihai16/symphony so issue state stays consistent and self-describing — apply missing labels, attach missing parent/child and blocker relationships, ensure every issue carries a priority, and reconcile superseding comments. Invoke on user keywords like "clean up issues", "issue hygiene", "audit the issues", or when an issue is found under-labelled / unlinked / priority-less mid-work. Pairs with manage-issue and the blocker/linking protocol (issue 30).
---

# Issue Hygiene (audit + cleanup)

Operationalizes the convention in issue 35. Keeps issues on `Mihai16/symphony`
consistent and self-describing: correctly labelled, structurally linked,
prioritised, and free of stale superseded comment noise. Reuses
`manage-issue` conventions (existing-labels-only, audit-trail-visible) and the
issue 30 linking protocol (native `blocked_by`, sub-issues, **database id not
number**).

This skill *fixes existing issues*. It does not change the blocker-linking
mechanics (owned by issue 30) or the general issue lifecycle (`manage-issue` /
`.claude/memory/workflow.md`).

## When to invoke

- User says "clean up the issues", "issue hygiene", "audit the issues", "make
  the issue state consistent".
- Mid-work you notice an issue is under-labelled, missing a priority, or
  missing an obvious parent/child or blocker link.
- Before relying on issue state (e.g. triage, planning) when that state looks
  inconsistent.

Default scope is the issue(s) the user named. Only sweep all open issues when
explicitly asked ("audit *all* the issues").

## Per-issue checklist

For each issue in scope, fetch it (`mcp__github__issue_read`, `get`;
`get_labels`, `get_sub_issues`, `get_comments` as needed) and detect + fix:

### 1. Missing labels

Apply appropriate labels that **already exist** on the repo — never invent
labels (per `manage-issue`). Learn the label vocabulary with
`mcp__github__list_issue_types` or by scanning recent issues. Add via
`mcp__github__issue_write` (method `update`).

### 2. `claude code web` label

Apply the existing `claude code web` label to any issue about `.claude/`,
skills/memory conventions, or coding-environment permissions (PAT, egress
allowlist, sandbox). When in doubt about whether an issue qualifies, it
probably does if it touches how Claude operates in this repo.

### 3. Missing priority

Every issue must carry a priority. If absent, assign one using the repo's
existing priority label/field vocabulary (discover it the same way as labels —
do not invent a new scheme). Pick the level the issue's content warrants;
note the assignment in a brief comment if the choice is non-obvious.

### 4. Missing parent/child relationship

Where a parent/child structure clearly exists (phased work under its umbrella,
a capture issue under the standing umbrella, a blocker under the blocked
issue), attach the child with `mcp__github__sub_issue_write`:

- `method: add`
- `issue_number` = the **parent issue** (PRs cannot be parents)
- `sub_issue_id` = the child's **database id** (not its number — fetch via
  `mcp__github__issue_read` if you only have the number)

Do not fabricate hierarchy where none clearly exists.

### 5. Missing blocker relationship

Where one issue genuinely blocks another, set the **native `blocked_by`**
dependency (per the issue 30 protocol):

```
gh api --method POST \
  repos/Mihai16/symphony/issues/<blocked#>/dependencies/blocked_by \
  -F issue_id=<blocking-issue DATABASE id>
gh api repos/Mihai16/symphony/issues/<blocked#>/dependencies/blocked_by   # verify
```

`-F` = typed integer (`-f` → `422`). `issue_id` is the **database id**, not
the number. A `403` on POST with a `200` on the identical `GET` is a PAT-scope
gap (report it) — *not* the issue 29 egress-allowlist failure. The native
dependency and the sub-issue link are the **only** mechanisms; never emulate
with `⛔`-style "blocked by" comments or "do not merge" body text.

## Comment reconciliation

When per-issue comments **conflict or supersede each other**, reduce noise
while preserving meaning. The frame you pick decides the action — get it right
before deleting anything.

### Supersession → collapse to latest (default)

A fact replaced by a newer fact. With **no explicit user instruction**, keep
only the **latest version** and delete the now-obsolete earlier comment(s)
(`mcp__github__issue_write` / the issue-comment delete path).

*Example (do collapse):* an early comment says "agents cannot assign
blockers"; a later one says "resolved — a PAT with issues-dependencies write
was introduced." Keep only the later comment.

### Fold into the body → only if asked up front

**Only if the user requests it from the start** with language like
"incorporate comments" (or similar): fold the surviving content into the
**issue body itself**, then delete the comments entirely (prefer no comments
at all). Do **not** do this unless explicitly requested at the outset — a
mid-stream "ok also tidy comments" is not the up-front instruction.

### Discussion → preserve both sides (never collapse)

Genuine discussion where both sides have standing — e.g. an
architectural-choice debate — is **not** supersession. Both positions matter:
do not combine them, do not delete an "outdated version", do not pick a
winner. Supersession (a fact replaced by a newer fact) and discussion
(competing considerations that coexist) are different frames; when unsure
which applies, treat it as discussion and leave it alone.

## Audit trail

Per `manage-issue`: keep the audit trail visible. When you delete superseded
comments or change scope-bearing state, that reduction is itself the record
(the surviving latest comment, the structural link). Do not silently strip
content the user has seen without the replacement making the change legible.

## Anti-patterns

- Inventing labels or a new priority scheme the repo doesn't already use.
- Using an issue's *number* where the sub-issue / dependency API needs its
  *database id*.
- Collapsing a genuine two-sided discussion as if it were supersession.
- Folding comments into the body without an explicit up-front request.
- Emulating blocker links with `⛔` / "do not merge" text instead of the
  native dependency or sub-issue.
- Fabricating parent/child hierarchy where none clearly exists.
- Sweeping every open issue when only one was named.

## References

- Issue 35 — the convention this skill operationalizes (child of umbrella
  issue 32).
- Issue 30 — blocker/linking protocol (native `blocked_by`, sub-issues,
  db-id-not-number).
- `.claude/skills/manage-issue/` — existing-labels-only, audit-trail-visible,
  issue create/update/close.
- `.claude/skills/blocker-protocol/` — blocker detection and linking.
- `.claude/memory/workflow.md` — issue lifecycle, blockers, the `#N`
  auto-close caveat.
