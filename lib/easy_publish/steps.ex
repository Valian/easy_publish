defmodule EasyPublish.Steps do
  @moduledoc """
  Default step list and step resolution for EasyPublish.

  ## Configuration

  Configure steps in your `config/config.exs`:

      # Replace default steps entirely
      config :easy_publish,
        steps: [
          EasyPublish.Steps.GitClean,
          EasyPublish.Steps.Tests,
          MyApp.CustomStep,
          EasyPublish.Steps.HexPublish
        ]

      # Or modify defaults
      config :easy_publish,
        prepend_steps: [MyApp.BeforeRelease],
        append_steps: [MyApp.NotifySlack],
        skip_steps: [EasyPublish.Steps.Dialyzer]
  """

  @default_steps [
    # Pre-checks (run in check phase)
    EasyPublish.Steps.GitClean,
    EasyPublish.Steps.GitBranch,
    EasyPublish.Steps.GitUpToDate,
    EasyPublish.Steps.Tests,
    EasyPublish.Steps.Format,
    EasyPublish.Steps.Credo,
    EasyPublish.Steps.Dialyzer,
    EasyPublish.Steps.Changelog,
    EasyPublish.Steps.HexBuild,
    # Release actions (run in run phase)
    EasyPublish.Steps.UpdateVersion,
    EasyPublish.Steps.GitCommit,
    EasyPublish.Steps.GitTag,
    EasyPublish.Steps.GitPush,
    EasyPublish.Steps.GitHubRelease,
    EasyPublish.Steps.HexPublish
  ]

  @doc """
  Returns the default step list.
  """
  def default_steps, do: @default_steps

  @doc """
  Resolves the step list based on application configuration.

  Supports three modes:
  - `steps: [...]` - Replace all default steps
  - `prepend_steps`, `append_steps`, `skip_steps` - Modify default steps
  - No config - Use default steps
  """
  def resolve_steps do
    case Application.get_env(:easy_publish, :steps) do
      nil ->
        @default_steps
        |> prepend_steps()
        |> append_steps()
        |> skip_steps()

      steps when is_list(steps) ->
        steps
    end
  end

  defp prepend_steps(steps) do
    case Application.get_env(:easy_publish, :prepend_steps) do
      nil -> steps
      prepend when is_list(prepend) -> prepend ++ steps
    end
  end

  defp append_steps(steps) do
    case Application.get_env(:easy_publish, :append_steps) do
      nil -> steps
      append when is_list(append) -> steps ++ append
    end
  end

  defp skip_steps(steps) do
    case Application.get_env(:easy_publish, :skip_steps) do
      nil -> steps
      skip when is_list(skip) -> Enum.reject(steps, &(&1 in skip))
    end
  end
end
