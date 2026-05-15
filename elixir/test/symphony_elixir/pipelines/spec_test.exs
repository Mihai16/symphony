defmodule SymphonyElixir.Pipelines.SpecTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Config.Schema
  alias SymphonyElixir.Pipelines.Spec

  describe "resolve/1" do
    test "synthesises __default_codex from the legacy codex block when no pipeline is selected" do
      assert {:ok, settings} =
               Schema.parse(%{
                 codex: %{
                   command: "codex app-server --legacy",
                   thread_sandbox: "workspace-write",
                   turn_timeout_ms: 1_234,
                   read_timeout_ms: 567,
                   stall_timeout_ms: 89
                 }
               })

      assert {:ok, %Spec{} = spec} = Spec.resolve(settings)
      assert spec.name == "__default_codex"
      assert spec.kind == "codex"
      assert spec.command == "codex app-server --legacy"
      assert spec.thread_sandbox == "workspace-write"
      assert spec.turn_timeout_ms == 1_234
      assert spec.read_timeout_ms == 567
      assert spec.stall_timeout_ms == 89
      assert spec.stages == []
      assert spec.max_internal_iterations == nil
      assert spec.review_threshold == nil
    end

    test "resolves explicit pipeline.use against a pipelines entry of kind codex" do
      assert {:ok, settings} =
               Schema.parse(%{
                 codex: %{command: "codex app-server"},
                 pipeline: %{use: "my-codex"},
                 pipelines: %{
                   "my-codex" => %{
                     kind: "codex",
                     command: "codex app-server --custom",
                     thread_sandbox: "workspace-write",
                     turn_timeout_ms: 42_000,
                     read_timeout_ms: 4_200,
                     stall_timeout_ms: 4_242
                   }
                 }
               })

      assert {:ok, %Spec{} = spec} = Spec.resolve(settings)
      assert spec.name == "my-codex"
      assert spec.kind == "codex"
      assert spec.command == "codex app-server --custom"
      assert spec.thread_sandbox == "workspace-write"
      assert spec.turn_timeout_ms == 42_000
      assert spec.read_timeout_ms == 4_200
      assert spec.stall_timeout_ms == 4_242
    end

    test "fills omitted Codex knobs from kind defaults" do
      assert {:ok, settings} =
               Schema.parse(%{
                 pipeline: %{use: "p1"},
                 pipelines: %{
                   "p1" => %{kind: "codex", command: "codex app-server"}
                 }
               })

      assert {:ok, %Spec{} = spec} = Spec.resolve(settings)
      assert spec.turn_timeout_ms == 3_600_000
      assert spec.read_timeout_ms == 5_000
      assert spec.stall_timeout_ms == 300_000
      assert spec.thread_sandbox == "workspace-write"
    end

    test "returns {:pipeline_unresolved, {:unknown, name}} when pipeline.use does not match" do
      assert {:ok, settings} =
               Schema.parse(%{
                 pipeline: %{use: "missing"},
                 pipelines: %{
                   "other" => %{kind: "codex", command: "codex app-server"}
                 }
               })

      assert {:error, {:pipeline_unresolved, {:unknown, "missing"}}} = Spec.resolve(settings)
    end

    test "returns {:pipeline_unresolved, :no_selection} when pipelines exist but pipeline.use is unset" do
      assert {:ok, settings} =
               Schema.parse(%{
                 pipelines: %{
                   "p1" => %{kind: "codex", command: "codex app-server"}
                 }
               })

      assert {:error, {:pipeline_unresolved, :no_selection}} = Spec.resolve(settings)
    end

    test "carries unsupported kind values through so validation can reject them" do
      assert {:ok, settings} =
               Schema.parse(%{
                 pipeline: %{use: "weird"},
                 pipelines: %{
                   "weird" => %{kind: "weird-runner", command: "weird-runner --serve"}
                 }
               })

      assert {:ok, %Spec{kind: "weird-runner"}} = Spec.resolve(settings)
    end

    test "carries claude-pipeline fields through" do
      assert {:ok, settings} =
               Schema.parse(%{
                 pipeline: %{use: "claude"},
                 pipelines: %{
                   "claude" => %{
                     kind: "claude-pipeline",
                     command: "claude-pipeline serve",
                     stages: ["implement", "review"],
                     max_internal_iterations: 3,
                     review_threshold: 0.8
                   }
                 }
               })

      assert {:ok, %Spec{} = spec} = Spec.resolve(settings)
      assert spec.kind == "claude-pipeline"
      assert spec.stages == ["implement", "review"]
      assert spec.max_internal_iterations == 3
      assert spec.review_threshold == 0.8
    end
  end
end
