defmodule SymphonyElixir.Pipelines.Runner do
  @moduledoc """
  Behaviour implemented by pipeline runners.

  A runner owns the per-worker execution strategy for a resolved
  `SymphonyElixir.Pipelines.Spec`. `AgentRunner` resolves the active spec, picks
  the runner keyed on `spec.kind`, and delegates the workspace-bound run to
  `c:run/4`.

  ## Opts

  The keyword list passed as the final argument carries the run context:

    * `:codex_update_recipient` - pid that should receive `{:codex_worker_update, ...}`
      and `{:pipeline_runtime_info, ...}` messages, or `nil` to run silently.
    * `:worker_host` - SSH host the run executes on, or `nil` for local execution.
    * `:max_turns` - upper bound on continuation turns; defaults to
      `Config.settings!().agent.max_turns` when absent.
    * `:issue_state_fetcher` - 1-arity function used to refresh issue state between
      turns; defaults to `&Tracker.fetch_issue_states_by_ids/1` when absent.
  """

  alias SymphonyElixir.Pipelines.Spec

  @callback run(Spec.t(), Path.t(), map(), keyword()) :: :ok | {:error, term()}
end
