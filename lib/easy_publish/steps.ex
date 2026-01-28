defmodule EasyPublish.Steps do
  @moduledoc """
  Step lists for EasyPublish pipelines.

  Two pipelines:
  - **Check pipeline**: Validations that run before any changes are made
  - **Release pipeline**: Mutations that perform the actual release

  ## Configuration

  Configure steps in your `config/config.exs`:

      # Replace all steps entirely
      config :easy_publish,
        check_steps: [...],
        release_steps: [...]

      # Or modify defaults
      config :easy_publish,
        prepend_check_steps: [MyApp.BeforeChecks],
        append_release_steps: [MyApp.NotifySlack],
        skip_steps: [EasyPublish.Steps.Dialyzer]
  """

  @check_steps [
    EasyPublish.Steps.GitClean,
    EasyPublish.Steps.GitBranch,
    EasyPublish.Steps.GitUpToDate,
    EasyPublish.Steps.Tests,
    EasyPublish.Steps.Format,
    EasyPublish.Steps.Credo,
    EasyPublish.Steps.Dialyzer,
    EasyPublish.Steps.ChangelogValid,
    EasyPublish.Steps.HexBuild
  ]

  @release_steps [
    EasyPublish.Steps.UpdateVersion,
    EasyPublish.Steps.ChangelogUpdate,
    EasyPublish.Steps.GitCommit,
    EasyPublish.Steps.GitTag,
    EasyPublish.Steps.GitPush,
    EasyPublish.Steps.GitHubRelease,
    EasyPublish.Steps.HexPublish
  ]

  @doc """
  Returns the default check steps.
  """
  def default_check_steps, do: @check_steps

  @doc """
  Returns the default release steps.
  """
  def default_release_steps, do: @release_steps

  @doc """
  Resolves the check step list based on application configuration.
  """
  def resolve_check_steps do
    case Application.get_env(:easy_publish, :check_steps) do
      nil ->
        @check_steps
        |> prepend_steps(:prepend_check_steps)
        |> append_steps(:append_check_steps)
        |> skip_steps()

      steps when is_list(steps) ->
        steps
    end
  end

  @doc """
  Resolves the release step list based on application configuration.
  """
  def resolve_release_steps do
    case Application.get_env(:easy_publish, :release_steps) do
      nil ->
        @release_steps
        |> prepend_steps(:prepend_release_steps)
        |> append_steps(:append_release_steps)
        |> skip_steps()

      steps when is_list(steps) ->
        steps
    end
  end

  defp prepend_steps(steps, config_key) do
    case Application.get_env(:easy_publish, config_key) do
      nil -> steps
      prepend when is_list(prepend) -> prepend ++ steps
    end
  end

  defp append_steps(steps, config_key) do
    case Application.get_env(:easy_publish, config_key) do
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
