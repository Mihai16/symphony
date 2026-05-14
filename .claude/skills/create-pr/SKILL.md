---
name: create-pr
description: Open a pull request on Mihai16/symphony with a body that passes the repo's `pr-description-lint` check on the first try. Use whenever the user asks to "open a PR", "ship it", "create a pull request", or similar. Pairs with manage-issue (the PR should close an issue) and start-issue-branch (the branch the PR is built on).
---

# Create a Pull Request

The repo runs `pr-description-lint` (`.github/workflows/pr-description-lint.yml`) on every PR. It
executes `mix pr_body.check` against `.github/pull_request_template.md`. Bodies that don't match
the template fail before any other check runs. This skill keeps you out of the rework loop.

## When to invoke

- User says "open a PR", "create the pull request", "ship it", "submit it".
- A branch has been pushed and the user wants it merged.

Do **not** invoke when:

- The user only asked you to push a branch (push, then stop).
- No issue exists for the work and the user hasn't explicitly authorised opening one (per
  `.claude/memory/workflow.md`, PRs are created only when the user asks).

## Procedure

### Step 1 — Read the template, fresh

Always re-read `.github/pull_request_template.md` before composing the body. The required
headings, their level (currently `####`), their order, and the section-specific rules (bullets,
checkboxes) come from this file — do not work from memory.

### Step 2 — Compose the body to the lint rules

The lint enforced by `elixir/lib/mix/tasks/pr_body.check.ex`:

| Rule                                            | What it means                                                          |
|-------------------------------------------------|------------------------------------------------------------------------|
| Required headings present                       | Every `#### …` heading in the template must appear verbatim.           |
| Order matches template                          | Headings appear in the same order as the template.                     |
| No `<!--` placeholders                          | Strip every comment from the template; don't leave a single `<!--`.    |
| No empty sections                               | Every heading needs at least one non-whitespace line under it.         |
| `Summary` requires bullets                      | At least one `- …` line under `#### Summary`.                          |
| `Test Plan` requires checkboxes                 | At least one `- [ ] …` or `- [x] …` line under `#### Test Plan`.       |

Plain bullets in `Test Plan` are the most common failure. Even if the item is already done, use
`- [x] …`, not `- …`.

### Step 3 — Apply workflow.md conventions on top

From `.claude/memory/workflow.md`:

- **Body opens with `Closes #<n>`** (or `Fixes #N` / `Resolves #N`). If the PR resolves multiple
  issues, list each: `Closes #N, Closes #M`. Skip only if no issue exists.
- **Title** matches the issue title or a close rewording. Keep under 70 chars.
- **One PR per issue.** If scope grows, file a follow-up issue (`manage-issue`); don't expand the
  PR.

### Step 4 — Footer

Append the session-link footer the harness expects:

```
https://claude.ai/code/session_<id>
```

The exact session ID is the one from this conversation's earlier git commits.

### Step 5 — Body skeleton (paste-ready)

Fill every section — none may be empty. Replace the placeholder text; do not leave any `<!--`
comments behind.

```markdown
Closes #<N>

#### Context

<Why is this change needed? ≤ 240 chars. Plain paragraph.>

#### TL;DR

*<One short sentence describing the change. ≤ 120 chars.>*

#### Summary

- <High-level change 1. ≤ 120 chars.>
- <High-level change 2.>
- <High-level change 3.>

#### Alternatives

- <Alternative considered and why it was rejected.>

#### Test Plan

- [ ] `make -C elixir all`
- [x] <Targeted check you already ran locally.>
- [ ] <Targeted check that will run on CI or after merge.>

https://claude.ai/code/session_<id>
```

### Step 6 — Self-lint before submitting

Before calling `mcp__github__create_pull_request`, scan the body once more:

- Search for `<!--`. If present → strip.
- Confirm every `####` heading from the template is present, spelled exactly, in order.
- Confirm `#### Summary` has at least one `- ` bullet.
- Confirm `#### Test Plan` has at least one `- [ ] ` or `- [x] ` checkbox.
- Confirm the body opens with `Closes #N` (unless explicitly no issue).
- Confirm the title is ≤ 70 chars.

### Step 7 — Open the PR

Use `mcp__github__create_pull_request` with `base: main` and the pushed branch as `head`. Pass
the body via a single string (markdown), not piped through the shell.

### Step 8 — After opening

- Report the PR URL to the user.
- Ask if they'd like the session subscribed to PR activity (`mcp__github__subscribe_pr_activity`)
  to auto-respond to CI failures and review comments.

## If `pr-description-lint` still fails

The check's failure log lists the specific rule that fired. Re-read it, fix the body in place
with `mcp__github__update_pull_request`, and the check re-runs on the synchronize event — no
push needed.
