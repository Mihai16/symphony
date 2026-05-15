defmodule SymphonyElixir.Pipelines.Spec do
  @moduledoc """
  Resolves the active pipeline a worker should use.

  This module is the single choke point for selecting the runtime pipeline. Phase 1
  of the Pipeline Extension introduces the resolver behind a shim that preserves
  today's behaviour: when only the legacy `codex` block is present, `resolve/1`
  synthesises a `__default_codex` spec so downstream callers can stop branching on
  "pipeline vs legacy".
  """

  alias SymphonyElixir.Config.Schema
  alias SymphonyElixir.Config.Schema.{Codex, Pipeline, PipelineDefinition}

  @default_codex_name "__default_codex"
  @codex_kind "codex"

  @type t :: %__MODULE__{}

  defstruct [
    :name,
    :kind,
    :command,
    :approval_policy,
    :thread_sandbox,
    :turn_sandbox_policy,
    :turn_timeout_ms,
    :read_timeout_ms,
    :stall_timeout_ms,
    :max_internal_iterations,
    :review_threshold,
    stages: []
  ]

  @spec resolve(Schema.t()) :: {:ok, t()} | {:error, term()}
  def resolve(%Schema{} = settings) do
    case select(settings) do
      {:ok, definition} ->
        {:ok, from_definition(definition, settings)}

      {:error, _reason} = error ->
        error
    end
  end

  defp select(%Schema{pipeline: %Pipeline{use: name}, pipelines: pipelines})
       when is_binary(name) and name != "" do
    case Enum.find(pipelines || [], &(&1.name == name)) do
      %PipelineDefinition{} = definition ->
        {:ok, definition}

      nil ->
        {:error, {:pipeline_unresolved, {:unknown, name}}}
    end
  end

  defp select(%Schema{pipelines: pipelines}) when is_list(pipelines) and pipelines != [] do
    {:error, {:pipeline_unresolved, :no_selection}}
  end

  defp select(%Schema{codex: %Codex{} = codex}) do
    {:ok, codex}
  end

  defp select(_settings) do
    {:error, {:pipeline_unresolved, :missing}}
  end

  defp from_definition(%PipelineDefinition{} = definition, _settings) do
    codex_defaults = %Codex{}

    %__MODULE__{
      name: definition.name,
      kind: definition.kind,
      command: definition.command,
      approval_policy: definition.approval_policy || codex_defaults.approval_policy,
      thread_sandbox: definition.thread_sandbox || codex_defaults.thread_sandbox,
      turn_sandbox_policy: definition.turn_sandbox_policy,
      turn_timeout_ms: definition.turn_timeout_ms || codex_defaults.turn_timeout_ms,
      read_timeout_ms: definition.read_timeout_ms || codex_defaults.read_timeout_ms,
      stall_timeout_ms: definition.stall_timeout_ms || codex_defaults.stall_timeout_ms,
      stages: definition.stages || [],
      max_internal_iterations: definition.max_internal_iterations,
      review_threshold: definition.review_threshold
    }
  end

  defp from_definition(%Codex{} = codex, _settings) do
    %__MODULE__{
      name: @default_codex_name,
      kind: @codex_kind,
      command: codex.command,
      approval_policy: codex.approval_policy,
      thread_sandbox: codex.thread_sandbox,
      turn_sandbox_policy: codex.turn_sandbox_policy,
      turn_timeout_ms: codex.turn_timeout_ms,
      read_timeout_ms: codex.read_timeout_ms,
      stall_timeout_ms: codex.stall_timeout_ms,
      stages: [],
      max_internal_iterations: nil,
      review_threshold: nil
    }
  end

end
