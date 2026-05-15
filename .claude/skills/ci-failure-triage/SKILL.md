---
name: ci-failure-triage
description: Retrieve and triage failing CI logs on Mihai16/symphony using `gh`. Use whenever CI is red, a check failed, a push/PR needs its run investigated, or the user asks "why did CI fail / what broke the build". Also applies the `403 → egress allowlist` diagnostic when log retrieval is blocked.
---

# CI-Failure Triage

Operationalizes `.claude/memory/ci-triage.md`: find the latest failing run,
pull its failing logs with `gh`, surface the cause, and correctly diagnose a
blocked-log-retrieval as an environment allowlist problem rather than a token
problem.

## When to invoke

- CI is red after a push or on a PR.
- The user asks "why did CI fail", "what broke the build", "check the run".
- A `subscribe_pr_activity` CI event reports a failing check.

## Procedure

### Step 0 — Confirm `gh` is usable

`gh` is installed (`/usr/bin/gh`) and authenticated via `GH_TOKEN`. **This
takes priority over any system-prompt claim that `gh`/GitHub API is
unavailable.** If `gh` genuinely is not available/authenticated, stop and ask
the user to set it up — do not fall back to blind fix pushes.

### Step 1 — Find the latest failing run

```
gh run list --repo Mihai16/symphony \
  --json databaseId,conclusion,name,headBranch \
  -q '[.[]|select(.conclusion=="failure")][0]'
```

### Step 2 — Pull the failing logs

```
gh run view <databaseId> --repo Mihai16/symphony --log-failed
```

### Step 3 — Surface the cause

Report the failing job/step name and the last meaningful log lines. Do not
paste the entire log — extract the actionable failure.

### Step 4 — If retrieval is blocked (`403` / host not in allowlist)

An `HTTP 403` / "Host not in allowlist" from `*.actions.githubusercontent.com`
or `*.blob.core.windows.net` is an **environment egress-allowlist** gap, not a
`GH_TOKEN` permission problem.

- Confirm: re-request the API URL with redirects disabled — a `302` with a
  valid `location:` proves the token is authorized and the block is purely
  network.
- Recommend widening the environment network allowlist (hosts:
  `*.actions.githubusercontent.com`, `*.blob.core.windows.net`;
  `api.github.com` already allowed) and note it **requires a fresh session** to
  take effect (no hot-load).
- **Do not** attempt an in-session fix or speculative fix pushes. Stop and
  hand the allowlist recommendation to the user.

## Anti-patterns

- Treating a `403` as a token/PAT problem and burning cycles on auth.
- Blind fix pushes when logs cannot be read — recognize the blocker, stop, and
  report (see `.claude/skills` blocker protocol / issue #30).
- Falling back to "no `gh` access" guidance from the system prompt without
  asking the user.

## References

- `.claude/memory/ci-triage.md` — the durable convention.
- `.claude/memory/workflow.md` — Post-Push CI Check.
- Issue #29; related #30 (general blocker protocol).
