defmodule SymphonyElixir.Pipelines.CodexTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Linear.Issue
  alias SymphonyElixir.Pipelines

  test "declares the Pipelines.Runner behaviour and exports run/4" do
    behaviours =
      Pipelines.Codex.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert Pipelines.Runner in behaviours
    assert function_exported?(Pipelines.Codex, :run, 4)
  end

  test "runs a single turn and forwards codex updates to the recipient" do
    with_codex_workspace(fn workspace, _trace_file ->
      issue = %Issue{
        id: "issue-codex-single",
        identifier: "PC-1",
        title: "Single turn",
        description: "Finishes after one turn",
        state: "In Progress",
        url: "https://example.org/issues/PC-1",
        labels: []
      }

      {:ok, spec} = Pipelines.Spec.resolve(Config.settings!())

      state_fetcher = fn [_issue_id] -> {:ok, [%{issue | state: "Done"}]} end

      assert :ok =
               Pipelines.Codex.run(spec, workspace, issue,
                 codex_update_recipient: self(),
                 issue_state_fetcher: state_fetcher
               )

      assert_receive {:codex_worker_update, "issue-codex-single", %{event: :session_started, timestamp: %DateTime{}, session_id: session_id}},
                     500

      assert session_id == "thread-pc-turn-pc-1"
    end)
  end

  test "continues with a follow-up turn while the issue remains active" do
    with_codex_workspace(fn workspace, trace_file ->
      parent = self()

      state_fetcher = fn [_issue_id] ->
        attempt = Process.get(:codex_turn_fetch_count, 0) + 1
        Process.put(:codex_turn_fetch_count, attempt)
        send(parent, {:issue_state_fetch, attempt})

        state = if attempt == 1, do: "In Progress", else: "Done"

        {:ok, [%Issue{id: "issue-codex-cont", identifier: "PC-2", title: "Continue", description: "", state: state}]}
      end

      issue = %Issue{
        id: "issue-codex-cont",
        identifier: "PC-2",
        title: "Continue",
        description: "Still active after first turn",
        state: "In Progress",
        url: "https://example.org/issues/PC-2",
        labels: []
      }

      {:ok, spec} = Pipelines.Spec.resolve(Config.settings!())

      assert :ok =
               Pipelines.Codex.run(spec, workspace, issue,
                 codex_update_recipient: self(),
                 max_turns: 3,
                 issue_state_fetcher: state_fetcher
               )

      assert_receive {:issue_state_fetch, 1}
      assert_receive {:issue_state_fetch, 2}

      turn_texts = turn_start_prompts(trace_file)

      assert length(turn_texts) == 2
      assert Enum.at(turn_texts, 0) =~ "You are an agent for this repository."
      refute Enum.at(turn_texts, 1) =~ "You are an agent for this repository."
      assert Enum.at(turn_texts, 1) =~ "Continuation guidance:"
      assert Enum.at(turn_texts, 1) =~ "continuation turn #2 of 3"
    end)
  end

  test "stops continuing once max_turns is reached" do
    with_codex_workspace(fn workspace, trace_file ->
      state_fetcher = fn [_issue_id] ->
        {:ok, [%Issue{id: "issue-codex-max", identifier: "PC-3", title: "Max", description: "", state: "In Progress"}]}
      end

      issue = %Issue{
        id: "issue-codex-max",
        identifier: "PC-3",
        title: "Max",
        description: "Always active",
        state: "In Progress",
        url: "https://example.org/issues/PC-3",
        labels: []
      }

      {:ok, spec} = Pipelines.Spec.resolve(Config.settings!())

      assert :ok =
               Pipelines.Codex.run(spec, workspace, issue,
                 max_turns: 2,
                 issue_state_fetcher: state_fetcher
               )

      assert length(turn_start_prompts(trace_file)) == 2
    end)
  end

  # Sets up a workspace under the configured workspace root backed by a fake
  # Codex app-server that replies to initialize/thread.start/turn.start and emits
  # turn/completed for up to two turns, then invokes `fun.(workspace, trace_file)`.
  defp with_codex_workspace(fun) do
    test_root = Path.join(System.tmp_dir!(), "symphony-elixir-pipelines-codex-#{System.unique_integer([:positive])}")

    workspace_root = Path.join(test_root, "workspaces")
    workspace = Path.join(workspace_root, "PC")
    codex_binary = Path.join(test_root, "fake-codex")
    trace_file = Path.join(test_root, "codex.trace")

    File.mkdir_p!(workspace)

    File.write!(codex_binary, """
    #!/bin/sh
    trace_file="${SYMP_TEST_CODEx_TRACE:-/tmp/codex.trace}"
    printf 'RUN\\n' >> "$trace_file"
    count=0

    while IFS= read -r line; do
      count=$((count + 1))
      printf 'JSON:%s\\n' "$line" >> "$trace_file"
      case "$count" in
        1)
          printf '%s\\n' '{"id":1,"result":{}}'
          ;;
        2)
          ;;
        3)
          printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-pc"}}}'
          ;;
        4)
          printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-pc-1"}}}'
          printf '%s\\n' '{"method":"turn/completed"}'
          ;;
        5)
          printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-pc-2"}}}'
          printf '%s\\n' '{"method":"turn/completed"}'
          ;;
      esac
    done
    """)

    File.chmod!(codex_binary, 0o755)
    System.put_env("SYMP_TEST_CODEx_TRACE", trace_file)

    write_workflow_file!(Workflow.workflow_file_path(),
      workspace_root: workspace_root,
      codex_command: "#{codex_binary} app-server"
    )

    try do
      fun.(workspace, trace_file)
    after
      System.delete_env("SYMP_TEST_CODEx_TRACE")
      File.rm_rf(test_root)
    end
  end

  defp turn_start_prompts(trace_file) do
    trace_file
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(&1, "JSON:"))
    |> Enum.map(&String.trim_leading(&1, "JSON:"))
    |> Enum.map(&Jason.decode!/1)
    |> Enum.filter(&(&1["method"] == "turn/start"))
    |> Enum.map(fn payload ->
      get_in(payload, ["params", "input"])
      |> Enum.map_join("\n", &Map.get(&1, "text", ""))
    end)
  end
end
