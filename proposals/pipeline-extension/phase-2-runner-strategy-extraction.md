# Phase 2 — Runner Strategy Extraction

> Tracking issue: [#20](https://github.com/Mihai16/symphony/issues/20)
> Split from the [Pipeline Extension plan](../pipeline-extension-plan.md) §2 (Phase 2) and §3.4–3.7, §3.9.
> Depends on [Phase 1](./phase-1-schema-and-spec-resolver.md) ([#19](https://github.com/Mihai16/symphony/issues/19)).

## Summary

Phase 2 makes the strategy pattern observable. It introduces a
`SymphonyElixir.Pipelines.Runner` behaviour, lifts the existing Codex-specific
turn loop out of `AgentRunner` into a `SymphonyElixir.Pipelines.Codex` runner,
and turns `AgentRunner.run/3` into a thin dispatcher keyed on the resolved
`Pipelines.Spec.kind`. The Orchestrator's running-entry record and the
presenter's snapshot payload both gain additive `pipeline` / `pipeline_kind`
fields so dashboards can surface which pipeline executed each issue. No
Codex-protocol behaviour changes; `agent.max_turns` and the stall reconciliation
loop continue to apply with identical semantics.

The phase is intentionally additive: the resolver from Phase 1 still routes
legacy `codex`-block configurations through `Pipelines.Codex` via the
`__default_codex` shim, and the only public-surface change is two new optional
keys on each running entry.

## Goals

- Define a stable `Pipelines.Runner` behaviour with a single `run/4` callback so
  Phase 3 (`ClaudePipeline`) and any future kind can plug in without touching
  `AgentRunner` again.
- Move the inline Codex orchestration (`run_codex_turns/5`,
  `do_run_codex_turns/8`, `build_turn_prompt/4`, `continue_with_issue?/2`,
  Codex-only message helpers) into `SymphonyElixir.Pipelines.Codex` without
  changing observable behaviour.
- Make `Codex.AppServer.start_session/2` accept a per-call `:overrides` keyword
  so a runner can pass spec-derived `command`, timeouts, and sandbox knobs
  without mutating global config.
- Surface the active pipeline name and kind on each running entry (Orchestrator
  state and snapshot/presenter payload).
- Migrate the Orchestrator stall reconciliation (`Config.settings!().codex.stall_timeout_ms`)
  off the legacy global read and onto the per-run snapshot stashed at dispatch
  time, so in-flight runs honour the pipeline they were launched with.

## Non-Goals

- Adding a new pipeline kind. The `claude-pipeline` runner is Phase 3.
- Changing how workspaces are created, how `before_run` / `after_run` hooks
  fire, host selection, retry/backoff, or any Orchestrator-owned policy beyond
  the stall lookup.
- Modifying any Codex JSON-RPC message shapes, prompt content, or
  per-turn semantics. The lifted code is a verbatim move plus the new
  `:overrides` plumbing.
- Dynamic reload wiring for `pipeline.use` flips. That is Phase 4.
- Deleting the legacy `codex` top-level config block. It stays parseable; only
  the read sites are migrated through `Pipelines.Spec.resolve/1`.
- New SPEC.md sections. Those land alongside the visible feature in Phase 3
  per the plan §4.

## Files Touched

New modules:

- `elixir/lib/symphony_elixir/pipelines/runner.ex` — behaviour module.
- `elixir/lib/symphony_elixir/pipelines/codex.ex` — Codex runner extracted from
  `AgentRunner`.

Modified:

- `elixir/lib/symphony_elixir/agent_runner.ex`
  - `run/3` (lines 12–27) — unchanged outer shape.
  - `run_on_worker_host/4` (lines 29–47) — replaces the inline
    `run_codex_turns/5` call with a `Pipelines.Spec.resolve/1` →
    `pipeline_runner(spec).run(...)` dispatch.
  - Removes `run_codex_turns/5` (lines 79–90), `do_run_codex_turns/8`
    (lines 92–131), `build_turn_prompt/4` (lines 133–145),
    `continue_with_issue?/2` (lines 147–164), `active_issue_state?/1` (lines
    166–173), `codex_message_handler/2` (lines 49–53), `send_codex_update/3`
    (lines 55–61). All move into `Pipelines.Codex`.
  - Adds `send_pipeline_runtime_info/3` mirroring the existing
    `send_worker_runtime_info/4` (lines 63–77), which stays.
  - Keeps `selected_worker_host/2` (lines 175–189), `worker_host_for_log/1`
    (lines 191–192), `issue_context/1` (lines 200–202).
- `elixir/lib/symphony_elixir/codex/app_server.ex`
  - `start_session/2` (lines 39–67) — accepts `:overrides` keyword. When
    present, the override map's keys win over `session_policies/2` (lines
    265–271) for `approval_policy`, `thread_sandbox`, `turn_sandbox_policy`,
    `command`, `turn_timeout_ms`, `read_timeout_ms`, `stall_timeout_ms`.
  - `run_turn/4` (lines 69–140) — already accepts a keyword; no signature
    change. Per-turn timeout overrides (if needed) are read off the session
    struct populated by `start_session/2`.
- `elixir/lib/symphony_elixir/orchestrator.ex`
  - Running-entry record (built at dispatch, surfaced at snapshot ~lines
    1106–1127) gains `:pipeline`, `:pipeline_kind`, and
    `:stall_timeout_ms_snapshot`.
  - New `handle_info({:pipeline_runtime_info, issue_id, info}, state)` clause
    placed adjacent to the existing `:worker_runtime_info` handler (lines
    166–181). Same shape: ignore unknown issue ids, otherwise merge fields and
    notify the dashboard.
  - `reconcile_stalled_running_issues/1` (lines 448–465) — reads
    `stall_timeout_ms_snapshot` per running entry instead of the global
    `Config.settings!().codex.stall_timeout_ms`. When the snapshot is missing
    (legacy entries during rolling restart), falls back to the old global read.
  - Snapshot construction (lines 1106–1127) adds `pipeline:` and
    `pipeline_kind:` to each running map.
- `elixir/lib/symphony_elixir_web/presenter.ex`
  - `running_entry_payload/1` (lines 98–117) — adds
    `pipeline: Map.get(entry, :pipeline)` and
    `pipeline_kind: Map.get(entry, :pipeline_kind)`.
  - `running_issue_payload/1` (lines 131–148) — same two additive fields.

Tests (per plan §3.9):

- `elixir/test/symphony_elixir/pipelines/codex_test.exs` — new; absorbs the
  turn-loop and prompt-construction cases that currently live in
  `app_server_test.exs`.
- `elixir/test/symphony_elixir/agent_runner_test.exs` — extend with a dispatch
  test that asserts `Pipelines.Codex.run/4` is invoked for a `kind: codex`
  spec.
- `elixir/test/symphony_elixir/orchestrator_test.exs` — assert the snapshot
  payload includes `pipeline` / `pipeline_kind` and that the stall reconciler
  reads the per-entry snapshot.
- `elixir/test/symphony_elixir_web/presenter_test.exs` — assert presenter
  passes the two fields through additively (and tolerates missing keys).

## Detailed Change Set

### `Pipelines.Runner` Behaviour (new module)

`elixir/lib/symphony_elixir/pipelines/runner.ex`:

```elixir
defmodule SymphonyElixir.Pipelines.Runner do
  @moduledoc """
  Strategy contract for executing a single issue against a resolved
  pipeline spec. One implementation per supported `kind`.
  """

  alias SymphonyElixir.Pipelines.Spec

  @type opts :: [
          codex_update_recipient: pid() | nil,
          worker_host: String.t() | nil,
          max_turns: pos_integer(),
          issue_state_fetcher: ([String.t()] -> {:ok, [map()]} | {:error, term()})
        ]

  @type result :: :ok | {:error, term()}

  @callback run(spec :: Spec.t(), workspace :: Path.t(), issue :: map(), opts) :: result()
end
```

Opt semantics (every implementation MUST honour these; the dispatcher always
supplies all four):

- `:codex_update_recipient` — pid that receives `{:codex_worker_update,
  issue_id, update}` and `{:worker_runtime_info, ...}` messages. May be `nil`
  in tests; runners MUST treat `nil` as a no-op.
- `:worker_host` — already-selected SSH host (or `nil` for local). Runners do
  not re-select; the orchestrator pins host for the lifetime of the run.
- `:max_turns` — outer cap on issue-state-driven turn iterations. Pulled from
  `Config.settings!().agent.max_turns` by default. A runner MAY apply a
  tighter internal cap (Phase 3 will, via `max_internal_iterations`), but MUST
  NOT exceed this value.
- `:issue_state_fetcher` — function used to refresh the tracker issue between
  turns. Defaults to `&Tracker.fetch_issue_states_by_ids/1`; tests inject a
  stub.

Return values match the existing inline contract: `:ok` on a clean run,
`{:error, reason}` on any failure. `AgentRunner.run/3` (line 19) keeps its
current "raise on `{:error, _}`" behaviour, so runners MUST NOT `raise`
themselves.

### `Pipelines.Codex` Runner (extracted from AgentRunner)

`elixir/lib/symphony_elixir/pipelines/codex.ex` houses the lifted code. It
implements `Pipelines.Runner` and re-exports the Codex behaviour verbatim:

```elixir
defmodule SymphonyElixir.Pipelines.Codex do
  @behaviour SymphonyElixir.Pipelines.Runner

  alias SymphonyElixir.Codex.AppServer
  alias SymphonyElixir.{Pipelines.Spec, Tracker}

  @impl true
  def run(%Spec{} = spec, workspace, issue, opts) do
    recipient = Keyword.get(opts, :codex_update_recipient)
    worker_host = Keyword.get(opts, :worker_host)
    max_turns = Keyword.fetch!(opts, :max_turns)
    issue_state_fetcher = Keyword.fetch!(opts, :issue_state_fetcher)

    overrides = spec_to_overrides(spec)

    with {:ok, session} <-
           AppServer.start_session(workspace,
             worker_host: worker_host,
             overrides: overrides
           ) do
      try do
        run_turns(session, workspace, issue, recipient, opts, issue_state_fetcher,
          1, max_turns)
      after
        AppServer.stop_session(session)
      end
    end
  end

  # do_run_codex_turns/8, build_turn_prompt/4, continue_with_issue?/2,
  # codex_message_handler/2, send_codex_update/3, active_issue_state?/1,
  # normalize_issue_state/1, issue_context/1 — all moved verbatim from
  # AgentRunner with the recursive call renamed to run_turns/8.
end
```

`spec_to_overrides/1` is a single private function that maps `Spec` fields
onto the keys `AppServer.start_session/2` expects. For a `__default_codex`
spec, this is a no-op semantically — the resulting overrides match what
`session_policies/2` would have produced from the legacy `codex` block.

### AgentRunner Dispatch

`AgentRunner.run/3` (lines 12–27) and `run_on_worker_host/4` (lines 29–47)
keep their outer shape. The change is local to the `with` block at line 37:

```elixir
try do
  with :ok <- Workspace.run_before_run_hook(workspace, issue, worker_host),
       {:ok, spec} <- Pipelines.Spec.resolve(Config.settings!()) do
    send_pipeline_runtime_info(codex_update_recipient, issue, spec)

    pipeline_runner(spec).run(spec, workspace, issue,
      codex_update_recipient: codex_update_recipient,
      worker_host: worker_host,
      max_turns: Keyword.get(opts, :max_turns, Config.settings!().agent.max_turns),
      issue_state_fetcher:
        Keyword.get(opts, :issue_state_fetcher, &Tracker.fetch_issue_states_by_ids/1)
    )
  end
after
  Workspace.run_after_run_hook(workspace, issue, worker_host)
end
```

`pipeline_runner/1` is a private one-line dispatch:

```elixir
defp pipeline_runner(%Spec{kind: "codex"}), do: SymphonyElixir.Pipelines.Codex
defp pipeline_runner(%Spec{kind: kind}),
  do: raise ArgumentError, "no runner registered for pipeline kind #{inspect(kind)}"
```

`Config.validate!/0` (Phase 1, plan §3.3) already rejects unknown kinds before
dispatch, so the raise is defence in depth.

`send_pipeline_runtime_info/3` mirrors the existing `send_worker_runtime_info/4`
(lines 63–77) and emits `{:pipeline_runtime_info, issue_id, %{pipeline: name,
kind: kind}}` so the Orchestrator can populate the running-entry record before
the first Codex message arrives.

### Orchestrator: pipeline-aware running entry

The running-entry record built when an issue is dispatched gains three new
keys, all populated additively:

- `:pipeline` — the resolved spec name (`"__default_codex"` for legacy
  configs).
- `:pipeline_kind` — the resolved spec kind (`"codex"` today; `"claude-pipeline"`
  in Phase 3).
- `:stall_timeout_ms_snapshot` — the spec's `stall_timeout_ms` at dispatch
  time, frozen for the lifetime of the run.

The new `handle_info` clause sits next to lines 166–181:

```elixir
def handle_info({:pipeline_runtime_info, issue_id, info}, %{running: running} = state)
    when is_binary(issue_id) and is_map(info) do
  case Map.get(running, issue_id) do
    nil ->
      {:noreply, state}

    running_entry ->
      updated =
        running_entry
        |> maybe_put_runtime_value(:pipeline, info[:pipeline])
        |> maybe_put_runtime_value(:pipeline_kind, info[:kind])

      notify_dashboard()
      {:noreply, %{state | running: Map.put(running, issue_id, updated)}}
  end
end
```

`reconcile_stalled_running_issues/1` (line 448) changes its lookup from a
global read to a per-entry read:

```elixir
defp reconcile_stalled_running_issues(%State{} = state) do
  if map_size(state.running) == 0 do
    state
  else
    now = DateTime.utc_now()

    Enum.reduce(state.running, state, fn {issue_id, entry}, acc ->
      timeout_ms =
        Map.get(entry, :stall_timeout_ms_snapshot) ||
          Config.settings!().codex.stall_timeout_ms

      if timeout_ms <= 0 do
        acc
      else
        restart_stalled_issue(acc, issue_id, entry, now, timeout_ms)
      end
    end)
  end
end
```

The snapshot construction at lines 1106–1127 adds the two presenter-bound
fields:

```elixir
%{
  # ... existing keys ...
  pipeline: Map.get(metadata, :pipeline),
  pipeline_kind: Map.get(metadata, :pipeline_kind),
  # runtime_seconds last as today
}
```

### Presenter: additive `pipeline` / `pipeline_kind` fields

`running_entry_payload/1` (lines 98–117) and `running_issue_payload/1`
(lines 131–148) each gain two `Map.get/2` reads:

```elixir
pipeline: Map.get(entry, :pipeline),
pipeline_kind: Map.get(entry, :pipeline_kind),
```

Additivity contract: these fields are emitted as JSON `null` when absent
(legacy clients still see the same key set plus two ignorable nulls). No
existing field is renamed, removed, or restructured. Clients that parse the
snapshot with permissive decoders (the dashboard, the optional HTTP server)
keep working unchanged. A consumer that wants to surface pipeline information
opts in by reading the new keys.

### `Codex.AppServer.start_session/2` overrides option

Today `start_session/2` (lines 39–67) reads policy via `session_policies/2`
(lines 265–271), which calls `Config.codex_runtime_settings/2` and so reads
the global `codex` block. Phase 2 introduces a single new option,
`:overrides`, accepted as a keyword:

```elixir
def start_session(workspace, opts \\ []) do
  worker_host = Keyword.get(opts, :worker_host)
  overrides = Keyword.get(opts, :overrides, %{})

  with {:ok, expanded_workspace} <- validate_workspace_cwd(workspace, worker_host),
       {:ok, port} <- start_port(expanded_workspace, worker_host, overrides) do
    metadata = port_metadata(port, worker_host)

    with {:ok, base_policies} <- session_policies(expanded_workspace, worker_host),
         policies = Map.merge(base_policies, overrides),
         {:ok, thread_id} <- do_start_session(port, expanded_workspace, policies) do
      # ... unchanged session map, but read from `policies` ...
    end
  end
end
```

Recognized override keys: `:approval_policy`, `:thread_sandbox`,
`:turn_sandbox_policy`, `:command`, `:turn_timeout_ms`, `:read_timeout_ms`,
`:stall_timeout_ms`. Unknown keys are ignored (forward-compatible with future
runner-specific knobs). When `overrides` is empty (the default), behaviour is
byte-identical to today — required for the no-behaviour-change guarantee.

`start_port/3` gains a third arg so an override-supplied `command` can be used
in place of the default `codex app-server`. For Phase 2 the only caller
that supplies a command is, transitively, `Pipelines.Codex` via
`spec_to_overrides/1`, and for the `__default_codex` spec the command equals
the existing default — so again, no observable change.

## Acceptance Criteria

From the plan §2 Phase 2 "Acceptance:" line, plus implied criteria:

- Snapshot JSON includes `pipeline` and `pipeline_kind` for every running
  entry. For runs launched on the legacy `codex` block, the values are
  `"__default_codex"` and `"codex"` respectively.
- No Codex protocol behaviour has changed: existing `app_server_test.exs`
  passes unmodified (workspace guards, symlink escape, sandbox policies,
  JSON-RPC framing, tool-call execution).
- `agent.max_turns` continues to cap turns; `continue_with_issue?` retains
  its three-way `{:continue, _} | {:done, _} | {:error, _}` contract; the
  continuation prompt at lines 135–145 is emitted verbatim.
- Stall detection still fires; the per-entry `stall_timeout_ms_snapshot` is
  honoured, and entries missing the snapshot fall back to the global read.
- `AgentRunner.run/3` raises a `RuntimeError` on `{:error, _}` exactly as
  today; the dispatcher does not swallow runner errors.
- `Pipelines.Runner` behaviour compiles cleanly and `Pipelines.Codex`
  declares `@behaviour Pipelines.Runner`.
- `Codex.AppServer.start_session/2` accepts `:overrides` and behaves
  identically when the option is absent or `%{}`.
- Presenter additivity holds: snapshot decoders that ignore unknown keys
  observe no diff for previously-surfaced fields.

## Test Plan

Unit:

- `Pipelines.Codex.run/4` happy path with stubbed `AppServer` — verify the
  outer turn loop honours `max_turns` and refreshes the issue between turns
  via the supplied `issue_state_fetcher`.
- `Pipelines.Codex.run/4` error paths — `AppServer.start_session/2` returns
  `{:error, _}`; `run_turn/4` returns `{:error, _}`; tracker fetcher returns
  `{:error, _}`. All bubble up unchanged.
- `Pipelines.Codex.run/4` continuation prompt — assert turn 2 prompt matches
  the verbatim continuation block at AgentRunner lines 135–145.
- `Codex.AppServer.start_session/2` with `:overrides` — every recognized key
  takes precedence; unknown keys are ignored; absent option preserves legacy
  behaviour.
- `AgentRunner` dispatch — for `kind: "codex"` spec, `Pipelines.Codex.run/4`
  is invoked with the four required opts present.

Integration:

- Orchestrator stall reconciler — running entry with
  `stall_timeout_ms_snapshot: 100` triggers retry after 100 ms even when
  global config reads 60 000.
- Orchestrator snapshot — running entry surfaces `pipeline` /
  `pipeline_kind` after a `:pipeline_runtime_info` message arrives, before
  the first `:codex_worker_update`.
- Presenter — `running_entry_payload/1` and `running_issue_payload/1` emit
  the two new keys (with `nil` when absent), no other key is reordered or
  dropped.
- End-to-end (extends the existing live-e2e harness) — a single dispatch
  through the legacy `codex` config produces a snapshot entry whose
  `pipeline` is `"__default_codex"` and `pipeline_kind` is `"codex"`.

Migrated tests:

- The turn-loop and prompt-construction cases currently in
  `app_server_test.exs` move to `pipelines/codex_test.exs`. The remaining
  workspace/sandbox/JSON-RPC cases stay where they are.

## Dependencies

- **Phase 1 must land first.** The dispatcher calls `Pipelines.Spec.resolve/1`,
  which only exists after Phase 1 ships the resolver and the
  `__default_codex` shim.
- **Phase 3 depends on this phase.** `ClaudePipeline` registers as another
  `@behaviour Pipelines.Runner`; without the behaviour module and the
  `pipeline_runner/1` dispatch, there is nowhere to plug it in.
- **Phase 4 depends on this phase.** Operator-visible reload logging and
  preflight hardening assume the per-run snapshot semantics introduced here.

## Risks

- **Verbatim-move bugs.** Lifting `do_run_codex_turns/8` and friends out of
  `AgentRunner` is mechanical but easy to get subtly wrong (recursive call
  rename, alias updates, `Logger.metadata` defaults). Mitigation: keep the
  diff minimal — move first, refactor later — and run the existing E2E
  suite before merging.
- **Override merge semantics.** `Map.merge/2` lets overrides silently shadow
  base policies. If a future bug puts a stray key into overrides it could
  flip behaviour invisibly. Mitigation: whitelist the allowed override keys
  in `start_session/2` and drop anything else with a debug log.
- **Snapshot field drift.** A consumer that pattern-matches the snapshot map
  exactly (rather than reading individual keys) would break on the new
  fields. Mitigation: the only in-tree consumer is the presenter, which uses
  `Map.get/2`. External consumers are documented elsewhere as additive-safe.
- **Stall snapshot during rolling restart.** If the BEAM is restarted while
  runs are in flight, on recovery the `stall_timeout_ms_snapshot` will be
  absent. The fallback to the global read covers this; tested explicitly.
- **`Pipelines.Codex` ↔ `AppServer` cycle.** `Pipelines.Codex` calls
  `AppServer`, and `AppServer` may eventually want to reference
  pipeline-level metadata. Keep the dependency one-way for v1.

## Follow-ups (Phases 3 & 4)

- **Phase 3 — `ClaudePipeline` runner.** Adds a second module implementing
  `Pipelines.Runner`, reusing `AppServer` via the `:overrides` plumbing
  introduced here, and capping the outer turn loop by
  `min(spec.max_internal_iterations, agent.max_turns)`.
- **Phase 4 — Dynamic reload + validation hardening.** Wires `pipeline.use`
  changes into `WorkflowStore` reload, extends preflight, and logs
  pipeline-name changes between ticks. The per-run snapshot semantics this
  phase introduces are what make hot-reload safe (in-flight workers continue
  under their original pipeline).
