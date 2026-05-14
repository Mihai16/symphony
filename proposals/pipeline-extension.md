# Symphony Pipeline Extension Proposal

Status: Draft v0 (proposed extension to Symphony Service Specification)

Purpose: Allow `WORKFLOW.md` to declare multiple named agent pipelines and select one with a single
variable, so teams can swap between Codex, multi-stage Claude pipelines, or any other agent
execution strategy without changing the rest of the system.

## Motivation

The current specification ties the Agent Runner to a single execution strategy: a Codex app-server
subprocess that runs one agent across one or more turns on one thread. This is sufficient for the
default deployment, but it forces a single shape on every implementation.

In practice, teams want different agent execution strategies for different workflows:

- The default Codex single-agent turn loop.
- A Claude pipeline that runs an implementer followed by a reviewer, refining until a score
  threshold is met or a max iteration count is reached.
- A Claude pipeline that runs implement → document → review for workflows where documentation is
  part of the deliverable.
- Custom team-defined pipelines that compose roles in other orders.

These strategies share most of Symphony's surface area — workspaces, hooks, polling, retries,
reconciliation, observability — and differ only in what happens inside one worker attempt. That is
precisely the place where the strategy design pattern fits: name a strategy, register it, select it
with one variable, and let the rest of the system stay generic.

The existing `codex` block in `WORKFLOW.md` is essentially one strategy hardcoded into the schema.
This proposal generalizes it.

## Goals

- Allow `WORKFLOW.md` to declare any number of named agent pipelines.
- Allow the active pipeline to be selected with a single variable (`pipeline.use`).
- Allow new pipelines to be added by an implementation without changing the core schema.
- Allow pipeline switching to participate in dynamic reload — flipping `pipeline.use` between
  pipelines on a live deployment is supported and well-defined.
- Preserve backwards compatibility with workflow files that use the existing `codex` block.

## Non-Goals

- Defining a universal protocol that all pipelines must speak. Each pipeline `kind` brings its own
  protocol contract.
- Replacing the existing Codex contract in Section 10. Codex remains a fully supported pipeline
  kind.
- Prescribing which pipelines an implementation must support. Implementations declare the kinds
  they support; the workflow file references those kinds.

## Proposed Schema Changes

### `pipeline` (object, top-level)

New top-level key in the workflow front matter.

Fields:

- `use` (string)
  - REQUIRED when `pipelines` is present.
  - Names the active pipeline. Must match a key in the `pipelines` map.
  - Changes SHOULD be re-applied at runtime and affect future dispatch decisions, retry scheduling,
    and agent launches. In-flight worker sessions are not interrupted.

### `pipelines` (map, top-level)

New top-level key in the workflow front matter. A map from pipeline name to pipeline definition.

Each pipeline definition is an object with:

- `kind` (string)
  - REQUIRED.
  - Names the agent execution strategy. Implementations document which kinds they support.
  - Standardized kinds in this proposal:
    - `codex` — current Codex app-server contract from Section 10.
    - `claude-pipeline` — multi-stage Claude execution (see below).
  - Implementations MAY define additional kinds. Unsupported kinds fail dispatch preflight
    validation.
- `command` (string shell command)
  - REQUIRED.
  - The subprocess command to launch via `bash -lc <command>` in the workspace.
  - Replaces the per-kind default (for example `codex app-server` for `kind: codex`).
- Additional kind-specific fields as defined below.

The top-level keys for the most common pipeline kinds are documented here. Implementations adding
new kinds SHOULD document their field schema, defaults, validation rules, and dynamic-reload
semantics.

### `pipelines.<name>` when `kind: codex`

Fields mirror the existing top-level `codex` block:

- `command` (default: `codex app-server`)
- `approval_policy` (Codex `AskForApproval` value, default implementation-defined)
- `thread_sandbox` (Codex `SandboxMode` value, default implementation-defined)
- `turn_sandbox_policy` (Codex `SandboxPolicy` value, default implementation-defined)
- `turn_timeout_ms` (integer, default `3600000`)
- `read_timeout_ms` (integer, default `5000`)
- `stall_timeout_ms` (integer, default `300000`)

A pipeline with `kind: codex` is functionally equivalent to the existing top-level `codex` block
and uses the Agent Runner contract from Section 10.

### `pipelines.<name>` when `kind: claude-pipeline`

A multi-stage Claude execution pipeline. The launched subprocess speaks the Codex app-server
protocol on stdio (so Symphony's Agent Runner contract is preserved) and internally orchestrates
multiple sub-agent stages within each protocol-level turn.

Fields:

- `command` (string shell command)
  - REQUIRED.
  - Launches the Claude pipeline subprocess.
- `stages` (list of stage names)
  - REQUIRED.
  - Ordered list naming the stages the pipeline runs per iteration.
  - Standardized stage names: `implement`, `refine`, `review`, `document`.
  - Implementations MAY define additional stage names.
  - The first stage in the list is the *initial* stage for first iterations. Subsequent iterations
    SHOULD substitute `implement` with `refine` and re-run later stages.
- `max_internal_iterations` (positive integer)
  - Default: `5`
  - Caps how many refine-review (or equivalent) cycles the pipeline runs within one worker
    session, independent of Symphony's `agent.max_turns`.
- `review_threshold` (number)
  - OPTIONAL.
  - If the pipeline includes a `review` stage that emits a numeric score, the pipeline exits
    cleanly when the score reaches this threshold.
- `turn_timeout_ms` (integer)
  - Default: `3600000` (1 hour)
  - Applies to the outer protocol turn, which encompasses one full stage sequence.
- `stall_timeout_ms` (integer)
  - Default: `600000` (10 minutes, longer than Codex default to accommodate multi-stage cycles)
  - The Orchestrator enforces this based on event inactivity; the pipeline subprocess SHOULD emit
    progress notifications between stages to keep the event stream alive.

### Selection Semantics

The active pipeline is determined as follows:

1. If `pipeline.use` is present, look up `pipelines[pipeline.use]` and use it.
2. Otherwise, if the legacy `codex` top-level block is present, use it as an implicit pipeline of
   `kind: codex` named `__default_codex`.
3. Otherwise, dispatch preflight validation fails.

If both `pipeline.use` and `codex` are present, `pipeline.use` wins. The `codex` block is preserved
only for backwards compatibility and may be deprecated in a future revision.

## Backwards Compatibility

Existing `WORKFLOW.md` files using the legacy `codex` top-level block continue to work without
modification. The Agent Runner treats a workflow file without `pipeline`/`pipelines` as having an
implicit pipeline of `kind: codex` derived from the legacy `codex` block, with name
`__default_codex`.

Implementations MAY emit a deprecation warning if both `pipeline.use` and the legacy `codex` block
are present, encouraging migration to the new schema.

## Validation

The config layer's dispatch preflight validation (Section 6.3) is extended:

- If `pipelines` is present, `pipeline.use` MUST be present.
- `pipeline.use` MUST name a key in `pipelines`.
- The selected pipeline's `kind` MUST be a kind supported by the implementation.
- The selected pipeline's `command` MUST be non-empty.
- Kind-specific required fields MUST be present for the selected kind.

Validation failure causes the same behavior as other dispatch preflight failures: skip dispatch for
the current tick, keep reconciliation active, emit an operator-visible error.

## Dynamic Reload Semantics

Pipeline selection participates in the dynamic reload contract from Section 6.2:

- Changing `pipeline.use` to reference a different existing pipeline takes effect on the next
  dispatch decision.
- Adding a new pipeline to the `pipelines` map and pointing `pipeline.use` at it takes effect on
  the next dispatch decision.
- Editing fields within the currently selected pipeline (for example bumping
  `max_internal_iterations`) takes effect on the next worker launch.
- In-flight worker sessions are NOT interrupted when pipeline selection changes. The currently
  running worker finishes under its original pipeline; the next worker dispatched picks up the new
  selection.
- Invalid pipeline configuration falls back to last known good behavior per Section 6.2.

## Agent Runner Contract Changes

Section 10 ("Agent Runner Protocol") is extended to dispatch on pipeline `kind`.

- The Agent Runner now selects an inner runner implementation based on `pipelines[pipeline.use].kind`.
- Each kind defines its own contract for subprocess launch, session startup, and turn streaming.
- Symphony's outer contract — workspace cwd, lifecycle hooks, events upstream to the Orchestrator,
  workspace preservation across runs — applies to all kinds equally.
- For `kind: codex`, the contract in Section 10 applies unchanged.
- For `kind: claude-pipeline`, the launched subprocess MUST speak the Codex app-server protocol on
  stdio, so the existing Agent Runner machinery (event forwarding, session ID extraction, stall
  detection, timeouts) works without modification. The pipeline's internal stage orchestration is
  invisible to Symphony.

The Orchestrator does not change. It continues to launch one worker per dispatched issue and
observes the same event stream regardless of which pipeline kind is active.

## Prompt Template Composition

The Markdown body of `WORKFLOW.md` remains the per-issue prompt template, rendered with the
`issue` and `attempt` variables as in Section 5.4.

For multi-stage pipelines, the rendered template is treated as the *shared issue context*. Each
stage's sub-agent receives the rendered template plus stage-specific role instructions defined by
the pipeline kind. For example, a `claude-pipeline` with stages `[implement, review]` would send
the rendered template plus implementer instructions to the implementer sub-agent, and the rendered
template plus reviewer instructions to the reviewer sub-agent.

Stage-specific role instructions are owned by the pipeline kind's implementation, not by the
workflow file. This keeps the workflow body focused on issue context and team conventions while
the pipeline owns role differentiation.

A future revision MAY introduce per-stage prompt overrides in the pipeline definition for teams
that want full control over stage prompts. This proposal does not include that capability.

## Observability

Pipelines SHOULD surface stage progress through the existing event stream so that the Orchestrator
runtime state, logging, and snapshot API remain informative:

- Emit `notification` events at stage boundaries with concise summaries (for example
  `"implement stage complete"`, `"review score: 8/10"`).
- Forward token usage from underlying API calls so `codex_totals` continues to reflect true cost.
- Emit `turn_completed` when the outer stage sequence finishes.

The snapshot API response shape from Section 13.7.2 SHOULD additionally surface the active
pipeline name for each running session. Suggested addition to the running entry:

```json
{
  "issue_identifier": "MT-649",
  "pipeline": "claude-implement-document-review",
  "session_id": "thread-1-turn-1",
  ...
}
```

This is an additive change and does not break existing consumers.

## Examples

### Default Codex pipeline (explicit)

```yaml
---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: my-project

pipeline:
  use: codex-default

pipelines:
  codex-default:
    kind: codex
    command: codex app-server
    approval_policy: never
---

You are working on {{ issue.identifier }}: {{ issue.title }}.

{{ issue.description }}
```

### Claude implementer + reviewer

```yaml
---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: my-project

pipeline:
  use: claude-implement-review

pipelines:
  claude-implement-review:
    kind: claude-pipeline
    command: my-claude-runner --mode=ir
    stages:
      - implement
      - review
    max_internal_iterations: 5
    review_threshold: 8
---

You are working on {{ issue.identifier }}: {{ issue.title }}.

Team conventions: TypeScript, named exports, npm test for the test suite.

{{ issue.description }}
```

### Claude implementer + documenter + reviewer

```yaml
pipeline:
  use: claude-idr

pipelines:
  claude-idr:
    kind: claude-pipeline
    command: my-claude-runner --mode=idr
    stages:
      - implement
      - document
      - review
    max_internal_iterations: 4
    review_threshold: 9
```

### Multiple pipelines, one active

```yaml
pipeline:
  use: claude-idr

pipelines:
  codex-default:
    kind: codex
    command: codex app-server

  claude-ir:
    kind: claude-pipeline
    command: my-claude-runner --mode=ir
    stages: [implement, review]
    review_threshold: 8

  claude-idr:
    kind: claude-pipeline
    command: my-claude-runner --mode=idr
    stages: [implement, document, review]
    review_threshold: 9
```

Operators can flip `pipeline.use` between these without restart; in-flight work finishes under its
original pipeline, new work picks up the new selection.

## Test and Validation Matrix Additions

Extending Section 17.1 (Workflow and Config Parsing):

- Workflow with only legacy `codex` block continues to load and dispatch under implicit
  `__default_codex` pipeline.
- Workflow with `pipeline.use` and matching `pipelines` entry loads and dispatches under the
  selected pipeline.
- Workflow with `pipeline.use` referencing a missing pipeline name fails dispatch preflight
  validation with a typed error.
- Workflow with a pipeline of unsupported `kind` fails dispatch preflight validation.
- Dynamic reload that changes `pipeline.use` from one valid pipeline to another applies to future
  dispatches without restarting in-flight workers.
- Dynamic reload that changes `pipeline.use` to an invalid value keeps the last known good
  pipeline active and emits an operator-visible error.

Extending Section 17.5 (Coding-Agent App-Server Client):

- For each implemented pipeline kind, session startup, turn streaming, and event extraction follow
  the contract documented for that kind.
- For `kind: claude-pipeline`, the subprocess speaks the Codex app-server protocol on stdio and
  the Agent Runner forwards events without awareness of internal stage orchestration.

## Implementation Checklist Additions

Extending Section 18.1 (Required for Conformance) — only if the implementation chooses to ship
multi-pipeline support:

- Parse `pipeline.use` and `pipelines` top-level keys from workflow front matter.
- Dispatch on pipeline `kind` when launching the Agent Runner.
- Honor the backwards-compat shim for the legacy `codex` block.
- Apply pipeline selection changes via dynamic reload without restart.

An implementation that chooses to support only `kind: codex` may treat this entire proposal as
optional and continue to use the legacy `codex` block as before.

## Open Questions

- Should the spec standardize a small set of stage names (`implement`, `refine`, `review`,
  `document`, `test`) with documented role semantics, or leave stage names entirely to pipeline
  kinds?
- Should per-stage prompt overrides be part of v1 of this extension or deferred?
- Should `max_internal_iterations` be a top-level pipeline field or nested under a `loop` block to
  accommodate non-iterative pipelines that still want to share stages?
- Should the Orchestrator track an `iteration` counter for multi-stage pipelines alongside the
  existing `attempt` and `turn_count`, exposed via the snapshot API?

These are intended for resolution before v1 of the extension is finalized.
