# Pipeline Extension — Implementation Plan of Attack

Companion to [`pipeline-extension.md`](./pipeline-extension.md). Targets the Elixir reference
implementation in `elixir/`. Where the proposal describes the *contract*, this document describes
the *concrete change set*: which modules grow, which gain new behaviour, what gets extracted, and
in what order.

All file paths in this plan are relative to the repo root unless prefixed with `elixir/`.

---

## 1. Architectural Summary

The proposal is, fundamentally, a strategy-pattern factoring of `SymphonyElixir.AgentRunner`. The
current code path looks like:

```
Orchestrator.dispatch_issue/4                                       elixir/lib/symphony_elixir/orchestrator.ex
  → Task.Supervisor.start_child → AgentRunner.run/3                 elixir/lib/symphony_elixir/agent_runner.ex:13
    → Workspace.create_for_issue → before_run hook
    → run_codex_turns → AppServer.start_session                     elixir/lib/symphony_elixir/codex/app_server.ex:39
      → AppServer.run_turn (per turn, max_turns capped)             elixir/lib/symphony_elixir/codex/app_server.ex:69
    → after_run hook
```

`AgentRunner.run/3` hardcodes Codex (`alias SymphonyElixir.Codex.AppServer`,
`agent_runner.ex:7`; direct `AppServer.start_session` call at `agent_runner.ex:83`). To honour the
proposal, that inner block becomes a dispatch on the resolved pipeline `kind`. Everything outside
the inner block — workspace lifecycle, hooks, host selection, worker_runtime_info forwarding,
crash/retry handling owned by the Orchestrator — stays unchanged.

The work is therefore concentrated in five places:

1. Workflow front-matter parsing (add `pipeline`, `pipelines`; keep `codex` as a shim).
2. A new `PipelineSpec` resolver that converts schema into the runtime pipeline a worker uses.
3. A `Pipelines.Runner` behaviour with two implementations: `Codex` (current code, lifted) and
   `ClaudePipeline` (new wrapper around AppServer).
4. `AgentRunner` becomes a thin dispatcher to whichever runner the selected pipeline declares.
5. Snapshot API + presenter additive change to surface `pipeline` per running entry.

No Orchestrator changes are required for correctness; the only Orchestrator touch is plumbing the
selected pipeline name into the running-entry record so the presenter can read it.

---

## 2. Delivery Phases

The proposal is large but additive. Ship it in four small, independently-reviewable phases.

### Phase 1 — Schema + backwards-compat shim (no behaviour change)

Add `pipeline` and `pipelines` to `Config.Schema`. Build a `PipelineSpec` resolver that returns
either the configured pipeline or, when only the legacy `codex` block is present, a synthetic
`__default_codex` spec. Everything still routes through `AppServer` exactly as it does today; the
legacy code path is preserved behind the resolver.

Acceptance: existing tests pass unmodified; new parsing tests cover the shim; `pipeline.use`
pointing at a `kind: codex` pipeline behaves identically to the legacy block.

### Phase 2 — Strategy extraction (`Pipelines.Runner` behaviour + Codex runner)

Introduce `SymphonyElixir.Pipelines.Runner` behaviour and lift the current Codex-specific block
out of `AgentRunner.run_codex_turns/5` into `SymphonyElixir.Pipelines.Codex`. `AgentRunner.run/3`
dispatches on the resolved `PipelineSpec.kind`. Snapshot/presenter gains the `pipeline` field.

Acceptance: snapshot JSON includes `pipeline` for running entries; no Codex-protocol behaviour has
changed; `agent.max_turns` and stall detection still apply.

### Phase 3 — `claude-pipeline` runner

Add `SymphonyElixir.Pipelines.ClaudePipeline`. Because the proposal mandates that the launched
subprocess speaks the Codex app-server protocol on stdio (proposal §"Agent Runner Contract
Changes"), this runner is mostly a configuration adapter: it reuses `Codex.AppServer.start_session`
and `run_turn`, but with `command`, timeouts, and stall settings taken from the
`claude-pipeline` block, and with an iteration cap derived from `max_internal_iterations`
applied at the *outer* turn loop (each stage sequence is one protocol turn from Symphony's
perspective).

Acceptance: a synthetic test pipeline that runs `bash -c 'echo {} ; sleep 0.1'`-style JSON-RPC
mock can complete a turn and emit `notification` events that get forwarded.

### Phase 4 — Dynamic reload + validation hardening

Wire `pipeline.use` and `pipelines.<name>` changes into the existing `WorkflowStore` reload path.
Extend dispatch preflight (`Config.validate!/0`) with the validations from proposal §"Validation".
Add the test cases from proposal §"Test and Validation Matrix Additions".

Acceptance: editing `WORKFLOW.md` to flip `pipeline.use` takes effect on the next dispatch tick
without restart; an invalid edit logs an operator-visible error and leaves the last-good pipeline
selected.

Each phase is small enough to land as a single PR. Phases 1 and 2 are mandatory for shipping
multi-pipeline support; Phases 3 and 4 can land independently.

---

## 3. Detailed Change Set

### 3.1 Schema (`elixir/lib/symphony_elixir/config/schema.ex`)

The existing `Codex` embedded schema (`schema.ex:153-200`) keeps its fields and defaults. Add two
new modules and two new top-level embeds:

```elixir
defmodule Pipeline do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:use, :string)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:use], empty_values: [])
  end
end

defmodule PipelineDefinition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:kind, :string)
    field(:command, :string)
    # Codex-shared knobs (allow nil so we can fall back to defaults per-kind)
    field(:approval_policy, StringOrMap)
    field(:thread_sandbox, :string)
    field(:turn_sandbox_policy, :map)
    field(:turn_timeout_ms, :integer)
    field(:read_timeout_ms, :integer)
    field(:stall_timeout_ms, :integer)
    # claude-pipeline knobs
    field(:stages, {:array, :string})
    field(:max_internal_iterations, :integer)
    field(:review_threshold, :float)
  end

  def changeset(schema, attrs), do: # cast + validate_required([:kind, :command]) + per-kind checks
end
```

In the top-level `embedded_schema` block (`schema.ex:264-274`) add:

```elixir
embeds_one(:pipeline, Pipeline, on_replace: :update, defaults_to_struct: true)
embeds_many(:pipelines, PipelineDefinition, on_replace: :delete)
```

`embeds_many` is the natural fit because the YAML decodes to a map, and we want stable retrieval
by name; the parser will normalize the incoming `pipelines: %{name => def}` map into a list of
`PipelineDefinition{name: name, ...}` (add a `:name` field to `PipelineDefinition` for this).

`Schema.parse/1` (`schema.ex:276`) gains a normalization step before `changeset/1`:

- If `pipelines` is a map, convert to a list of definitions with `name` set.
- If only the legacy `codex` block exists, synthesize a one-element `pipelines` list named
  `__default_codex` and set `pipeline.use = "__default_codex"`. This single shim eliminates
  branching downstream.

The legacy `codex` block stays untouched — both for parsing and for `Config.codex_runtime_settings/2`
callers that have not been migrated yet (e.g. `Orchestrator.reconcile_stalled_running_issues/1`,
`orchestrator.ex:448-449`, which reads `Config.settings!().codex.stall_timeout_ms`). Migrate those
call sites in Phase 2.

### 3.2 PipelineSpec resolver — new module

Create `elixir/lib/symphony_elixir/pipelines/spec.ex`:

```elixir
defmodule SymphonyElixir.Pipelines.Spec do
  @type t :: %__MODULE__{
    name: String.t(),
    kind: String.t(),
    command: String.t(),
    approval_policy: term(),
    thread_sandbox: String.t() | nil,
    turn_sandbox_policy: map() | nil,
    turn_timeout_ms: pos_integer(),
    read_timeout_ms: pos_integer(),
    stall_timeout_ms: non_neg_integer(),
    stages: [String.t()],
    max_internal_iterations: pos_integer() | nil,
    review_threshold: float() | nil
  }

  defstruct [...]

  @spec resolve(SymphonyElixir.Config.Schema.t()) :: {:ok, t()} | {:error, term()}
  def resolve(settings), do: # selection semantics from proposal §"Selection Semantics"
end
```

`resolve/1` implements the three-step selection from proposal §"Selection Semantics":

1. If `settings.pipeline.use` is set and matches a `pipelines` entry, return it.
2. Else, if the legacy `codex` block is present (always true post-Phase-1 thanks to default
   struct), fall back to a spec derived from it.
3. Else, `{:error, {:pipeline_unresolved, :missing}}`.

`Spec.resolve/1` is the single choke point. Every consumer below calls it; no consumer pokes at
`settings.pipeline` or `settings.pipelines` directly.

### 3.3 Validation (`elixir/lib/symphony_elixir/config.ex`)

`validate!/0` (`config.ex:94`) already covers tracker prerequisites in `validate_semantics/1`
(`config.ex:117-134`). Extend it:

```elixir
defp validate_semantics(settings) do
  cond do
    is_nil(settings.tracker.kind) -> {:error, :missing_tracker_kind}
    # ... existing tracker checks ...
    true ->
      case Pipelines.Spec.resolve(settings) do
        {:ok, %Spec{kind: kind}} ->
          if kind in supported_kinds(), do: :ok, else: {:error, {:unsupported_pipeline_kind, kind}}
        {:error, reason} ->
          {:error, reason}
      end
  end
end

defp supported_kinds, do: ["codex", "claude-pipeline"]
```

`format_config_error/1` (`config.ex:136-153`) gains clauses for `{:pipeline_unresolved, _}`,
`{:unsupported_pipeline_kind, _}`, and `{:missing_pipeline_field, _, _}`. These error tuples are
what end up in operator logs via `Orchestrator.maybe_dispatch/1` (`orchestrator.ex:224-264`), so
the messages need to be self-explanatory.

### 3.4 Runner behaviour — new module

Create `elixir/lib/symphony_elixir/pipelines/runner.ex`:

```elixir
defmodule SymphonyElixir.Pipelines.Runner do
  alias SymphonyElixir.Pipelines.Spec

  @type opts :: keyword()
  @type result :: :ok | {:error, term()}

  @callback run(spec :: Spec.t(), workspace :: Path.t(), issue :: map(), opts) :: result()
end
```

Concrete implementations:

- `SymphonyElixir.Pipelines.Codex` (`elixir/lib/symphony_elixir/pipelines/codex.ex`) — receives
  what `AgentRunner.run_codex_turns/5` (`agent_runner.ex:79-90`) currently has inline. The session
  startup uses `Codex.AppServer.start_session/2` with options derived from the spec (command,
  timeouts) rather than reading `Config.settings!().codex` directly. `AppServer.start_session/2`
  is extended to accept these as keyword overrides; today the function reads them via
  `session_policies/2` from global config, so introduce a single `:overrides` option that takes
  precedence.

- `SymphonyElixir.Pipelines.ClaudePipeline`
  (`elixir/lib/symphony_elixir/pipelines/claude_pipeline.ex`) — wraps the same AppServer client,
  but:
  - launches `bash -lc <spec.command>` for the subprocess (so any executable that speaks the
    Codex app-server protocol works);
  - caps the outer turn loop by `min(spec.max_internal_iterations, agent.max_turns)` rather than
    only `agent.max_turns`;
  - applies `spec.turn_timeout_ms`, `spec.stall_timeout_ms` as overrides;
  - logs `pipeline.kind` and `spec.name` in every line via `Logger.metadata/1` so existing log
    grepping continues to work.

The two runners share enough that they can extract a common `do_turn_loop` helper in
`Pipelines.Runner` later, but for the first cut keep them separate — duplicated is better than the
wrong abstraction here, and the duplication is small.

### 3.5 AgentRunner dispatch (`elixir/lib/symphony_elixir/agent_runner.ex`)

The current `run_on_worker_host/4` (`agent_runner.ex:29-47`) keeps its structure. Replace the
inline `run_codex_turns/5` call (line 38) with a dispatcher:

```elixir
with :ok <- Workspace.run_before_run_hook(workspace, issue, worker_host),
     {:ok, spec} <- Pipelines.Spec.resolve(Config.settings!()) do
  send_pipeline_runtime_info(codex_update_recipient, issue, spec)
  pipeline_runner(spec).run(spec, workspace, issue,
    codex_update_recipient: codex_update_recipient,
    worker_host: worker_host,
    max_turns: Keyword.get(opts, :max_turns, Config.settings!().agent.max_turns),
    issue_state_fetcher: Keyword.get(opts, :issue_state_fetcher, &Tracker.fetch_issue_states_by_ids/1)
  )
end
```

`pipeline_runner/1` is a private function mapping kind → module: `"codex" -> Pipelines.Codex`,
`"claude-pipeline" -> Pipelines.ClaudePipeline`. Unknown kinds raise, but
`Config.validate!/0` already rejects them before dispatch, so this is defence in depth.

Move `do_run_codex_turns/8`, `build_turn_prompt/4`, and `continue_with_issue?/2`
(`agent_runner.ex:92-164`) into `Pipelines.Codex`. They are Codex-specific. The shared helpers
(`selected_worker_host/2`, `send_worker_runtime_info/4`, `worker_host_for_log/1`) stay in
`AgentRunner` because they apply to every pipeline.

`send_pipeline_runtime_info/3` is a new helper that mirrors `send_worker_runtime_info/4`
(`agent_runner.ex:63-77`); it sends `{:pipeline_runtime_info, issue_id, %{pipeline: name, kind:
kind}}` to the orchestrator process so the snapshot can surface it.

### 3.6 Orchestrator + Snapshot (`elixir/lib/symphony_elixir/orchestrator.ex`)

The running-entry record (`orchestrator.ex:1106-1127`) gains two fields: `pipeline` (string name)
and `pipeline_kind` (string). They are populated when the new
`{:pipeline_runtime_info, issue_id, _}` message is handled. Add a `handle_info/2` clause adjacent
to the existing worker runtime info handler.

`reconcile_stalled_running_issues/1` (`orchestrator.ex:448`) currently reads
`Config.settings!().codex.stall_timeout_ms`. Change it to read the active pipeline's
`stall_timeout_ms` via `Pipelines.Spec.resolve(Config.settings!())`. Per the proposal's dynamic
reload rules, in-flight workers continue under their original pipeline — so the per-running-entry
record SHOULD also stash the `stall_timeout_ms` value the worker was launched with, rather than
re-resolving each tick. Add `stall_timeout_ms_snapshot` to the running entry.

### 3.7 Presenter (`elixir/lib/symphony_elixir_web/presenter.ex`)

`running_entry_payload/1` (`presenter.ex:98-117`) — add `pipeline: Map.get(entry, :pipeline)` and
`pipeline_kind: Map.get(entry, :pipeline_kind)`. `running_issue_payload/1`
(`presenter.ex:131-148`) — same. Both are additive; existing clients that don't read these fields
are unaffected.

### 3.8 Dynamic reload (`elixir/lib/symphony_elixir/workflow_store.ex`)

No changes to `WorkflowStore` itself: it already polls `WORKFLOW.md` mtime/size/hash every 1 s
(per the explore report). What changes is what consumers do at the next tick. Since
`Pipelines.Spec.resolve/1` reads `Config.settings!()` (which reads `Workflow.current/0`), the
moment `WorkflowStore` accepts a new parse, the next call to `Spec.resolve/1` returns the new
spec. The proposal's "in-flight workers are not interrupted" rule is satisfied automatically
because `AgentRunner.run/3` resolves the spec *once*, at the start of the run, and passes that
spec down to the runner — it never re-resolves mid-run.

The one piece worth adding: `Orchestrator.refresh_runtime_config/1` (the per-tick refresh
mentioned in the explore report) SHOULD log a single info-level line when the resolved pipeline
name or kind changes between ticks. That makes operator-visible reload events traceable from logs
alone.

### 3.9 Tests

Group new tests by phase. Test modules to create:

- `elixir/test/symphony_elixir/pipelines/spec_test.exs` — resolver unit tests covering all three
  branches of selection semantics (explicit `pipeline.use`, legacy `codex` shim, error case).
- `elixir/test/symphony_elixir/pipelines/codex_test.exs` — lift the relevant existing tests from
  `app_server_test.exs` that exercise the turn loop and prompt construction; they belong with the
  runner now.
- `elixir/test/symphony_elixir/pipelines/claude_pipeline_test.exs` — a stub subprocess (a small
  Elixir script under `test/support/`) that speaks just enough of the Codex JSON-RPC protocol to
  drive a turn to completion. Used to verify `command` override, `max_internal_iterations`
  capping, and stage-boundary `notification` forwarding.
- `elixir/test/symphony_elixir/workspace_and_config_test.exs` — extend the existing parsing tests
  with the six cases from proposal §"Test and Validation Matrix Additions".

Existing tests that should keep passing without modification: `core_test.exs`, `live_e2e_test.exs`,
and the bulk of `app_server_test.exs` (workspace guards, symlink escape, sandbox policies — none
of which the strategy refactor touches).

---

## 4. SPEC.md Edits

These edits land alongside Phase 2 (when the behaviour first becomes observable):

- **§5.3 Front Matter Schema** (line 326) — append `pipeline` and `pipelines` key definitions
  mirroring proposal §"Proposed Schema Changes". The existing `codex` block keeps its full
  description with a leading "DEPRECATED in favour of `pipelines.<name>` with `kind: codex`; still
  honoured for backwards compatibility" note.
- **§6.2 Dynamic Reload Semantics** (line 522) — append the four-bullet list from proposal
  §"Dynamic Reload Semantics".
- **§6.3 Dispatch Preflight Validation** (line 542) — append the five-bullet validation list from
  proposal §"Validation".
- **§10 Agent Runner Protocol** (line 906) — insert a new §10.0 "Pipeline Dispatch" that
  describes the kind-based dispatch and points at §10.1+ as the contract that applies to
  `kind: codex` (and any kind that speaks the Codex app-server protocol).
- **§13.7 OPTIONAL HTTP Server Extension** — note the additive `pipeline` and `pipeline_kind`
  fields on each running entry.
- **§17.1 / §17.5** — append the six matrix entries from proposal §"Test and Validation Matrix
  Additions".
- **§18.1 REQUIRED for Conformance** (line 2068) — leave unchanged. The proposal explicitly makes
  multi-pipeline support optional; only implementations that ship it must follow §18 additions
  from proposal §"Implementation Checklist Additions". Add those under §18.2 RECOMMENDED
  Extensions (line 2089) instead.

The SPEC.md edits are mechanical once the code lands; don't write them ahead of the code or they
will drift.

---

## 5. Resolutions for the Proposal's Open Questions

The proposal leaves four questions open. Recommended resolutions for v1, all reversible later:

- **Standardize stage names?** Yes, but loosely. Reserve `implement`, `refine`, `review`,
  `document`, `test` with documented semantics inside `ClaudePipeline`. Allow arbitrary additional
  names — they are passed through to the subprocess uninterpreted. This keeps the schema
  permissive while giving operators a known vocabulary.
- **Per-stage prompt overrides?** Defer. Pipeline kinds own role differentiation in v1 (matches
  the proposal's framing). Adding overrides later is purely additive.
- **`max_internal_iterations` under a `loop` block?** No. Keep it top-level for v1. Nesting can
  happen later if a non-iterative pipeline appears that wants to share stages. YAGNI today.
- **Track `iteration` in snapshot?** Yes — pipelines that emit `iteration_started` /
  `iteration_completed` `notification` events get a counter for free. Add `iteration` as an
  OPTIONAL field on the running entry, populated from the most recent observed event. Absent for
  pipelines that don't emit those events.

---

## 6. Risks and Mitigations

- **Schema migration drift.** The legacy `codex` block remains parseable but is now also reachable
  through the `__default_codex` synthetic pipeline. Two paths to the same behaviour invite
  divergence. *Mitigation:* `Spec.resolve/1` is the only function that reads either; all
  downstream consumers go through it. Phase 2 migrates the remaining direct
  `Config.settings!().codex.X` reads (the Orchestrator stall check is the biggest one).
- **`stall_timeout_ms` semantics for `claude-pipeline`.** The proposal sets the default to 10 min
  because stages take longer than single Codex turns, but the Orchestrator's stall check is purely
  event-driven. If a pipeline goes silent between stages without emitting `notification` events,
  it will be killed even though it is technically working. *Mitigation:* document explicitly in
  the `ClaudePipeline` module docstring that subprocesses MUST emit stage-boundary notifications,
  and add a Logger.warning if no event has been observed within `stall_timeout_ms / 2` to make the
  symptom diagnosable before it kills the run.
- **Hot reload across mismatched specs.** If an operator changes `pipeline.use` to a kind whose
  command is missing or unsupported, the next dispatch tick fails preflight (correct), but
  `Config.validate!/0` is called on *every* tick. *Mitigation:* the existing
  `Orchestrator.maybe_dispatch/1` (line 224-264) already handles preflight failure by skipping
  dispatch and keeping reconciliation active. The new validations slot into the same flow with no
  extra retry logic needed.
- **`embeds_many` with name keys.** Ecto's `embeds_many` is list-ordered; the YAML source is a
  map. The normalize step has to be deterministic across reloads. *Mitigation:* sort by name in
  the normalizer, and treat the list as a map at the API boundary. `Spec.resolve/1` does a
  `Enum.find/2` by name; nothing else iterates the list.

---

## 7. Out of Scope (Explicit)

- A universal pipeline protocol. The proposal explicitly disclaims this (§"Non-Goals"). Each kind
  keeps its own contract; the only thing they share is the outer Symphony surface
  (workspace, hooks, events).
- Replacing Codex. `kind: codex` remains a first-class pipeline and is the default in every
  generated example.
- A pipeline registry / plugin loader. v1 ships with the two kinds compiled in. New kinds require
  a module addition and a recompile. A plugin system can come later if there is demand from teams
  outside the reference implementation.
- Multi-process pipelines (one Symphony worker → N OS subprocesses). The proposal already
  constrains `claude-pipeline` to a single subprocess that speaks the Codex protocol; multi-proc
  fan-out is a separate proposal.

---

## 8. Concrete Next Step

Open a PR titled "Phase 1: Pipeline schema and spec resolver" containing only:

- `elixir/lib/symphony_elixir/config/schema.ex` — new `Pipeline`, `PipelineDefinition` embeds; the
  `normalize_pipelines` step in `Schema.parse/1`.
- `elixir/lib/symphony_elixir/pipelines/spec.ex` — new module.
- `elixir/lib/symphony_elixir/config.ex` — extended `validate_semantics/1` and
  `format_config_error/1`.
- `elixir/test/symphony_elixir/pipelines/spec_test.exs` — resolver tests.
- `elixir/test/symphony_elixir/workspace_and_config_test.exs` — six new parse/validate cases.

That PR has no behaviour change (no runner is invoked, no Codex code is moved). It establishes the
data model and validation contract so Phases 2-4 can land cleanly behind it.
