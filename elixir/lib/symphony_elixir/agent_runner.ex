defmodule SymphonyElixir.AgentRunner do
  @moduledoc """
  Executes a single Linear issue in its workspace with Codex.
  """

  require Logger
  alias SymphonyElixir.{Config, Linear.Issue, Pipelines, Workspace}

  @type worker_host :: String.t() | nil

  @spec run(map(), pid() | nil, keyword()) :: :ok | no_return()
  def run(issue, codex_update_recipient \\ nil, opts \\ []) do
    # The orchestrator owns host retries so one worker lifetime never hops machines.
    worker_host = selected_worker_host(Keyword.get(opts, :worker_host), Config.settings!().worker.ssh_hosts)

    Logger.info("Starting agent run for #{issue_context(issue)} worker_host=#{worker_host_for_log(worker_host)}")

    case run_on_worker_host(issue, codex_update_recipient, opts, worker_host) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Agent run failed for #{issue_context(issue)}: #{inspect(reason)}")
        raise RuntimeError, "Agent run failed for #{issue_context(issue)}: #{inspect(reason)}"
    end
  end

  defp run_on_worker_host(issue, codex_update_recipient, opts, worker_host) do
    Logger.info("Starting worker attempt for #{issue_context(issue)} worker_host=#{worker_host_for_log(worker_host)}")

    case Workspace.create_for_issue(issue, worker_host) do
      {:ok, workspace} ->
        send_worker_runtime_info(codex_update_recipient, issue, worker_host, workspace)

        try do
          with :ok <- Workspace.run_before_run_hook(workspace, issue, worker_host) do
            run_pipeline(workspace, issue, codex_update_recipient, opts, worker_host)
          end
        after
          Workspace.run_after_run_hook(workspace, issue, worker_host)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_pipeline(workspace, issue, codex_update_recipient, opts, worker_host) do
    case Pipelines.Spec.resolve(Config.settings!()) do
      {:ok, %Pipelines.Spec{} = spec} ->
        send_pipeline_runtime_info(codex_update_recipient, issue, spec)

        run_opts =
          opts
          |> Keyword.put(:codex_update_recipient, codex_update_recipient)
          |> Keyword.put(:worker_host, worker_host)

        pipeline_runner(spec).run(spec, workspace, issue, run_opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp pipeline_runner(%Pipelines.Spec{kind: "codex"}), do: Pipelines.Codex

  defp pipeline_runner(%Pipelines.Spec{kind: kind}) do
    raise ArgumentError, "unsupported pipeline kind: #{inspect(kind)}"
  end

  defp send_pipeline_runtime_info(recipient, %Issue{id: issue_id}, %Pipelines.Spec{} = spec)
       when is_binary(issue_id) and is_pid(recipient) do
    send(
      recipient,
      {:pipeline_runtime_info, issue_id,
       %{
         pipeline: spec.name,
         pipeline_kind: spec.kind,
         stall_timeout_ms: spec.stall_timeout_ms
       }}
    )

    :ok
  end

  defp send_pipeline_runtime_info(_recipient, _issue, _spec), do: :ok

  defp send_worker_runtime_info(recipient, %Issue{id: issue_id}, worker_host, workspace)
       when is_binary(issue_id) and is_pid(recipient) and is_binary(workspace) do
    send(
      recipient,
      {:worker_runtime_info, issue_id,
       %{
         worker_host: worker_host,
         workspace_path: workspace
       }}
    )

    :ok
  end

  defp send_worker_runtime_info(_recipient, _issue, _worker_host, _workspace), do: :ok

  defp selected_worker_host(nil, []), do: nil

  defp selected_worker_host(preferred_host, configured_hosts) when is_list(configured_hosts) do
    hosts =
      configured_hosts
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    case preferred_host do
      host when is_binary(host) and host != "" -> host
      _ when hosts == [] -> nil
      _ -> List.first(hosts)
    end
  end

  defp worker_host_for_log(nil), do: "local"
  defp worker_host_for_log(worker_host), do: worker_host

  defp issue_context(%Issue{id: issue_id, identifier: identifier}) do
    "issue_id=#{issue_id} issue_identifier=#{identifier}"
  end
end
