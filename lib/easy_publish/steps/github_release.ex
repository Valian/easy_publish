defmodule EasyPublish.Steps.GitHubRelease do
  @moduledoc """
  Creates a GitHub release using the gh CLI (if available).
  """

  use EasyPublish.Step, name: "Creating GitHub release"

  @impl true
  def options do
    [{:skip_github_release, type: :boolean, default: false, doc: "Skip GitHub release creation"}]
  end

  @impl true
  def execute(ctx) do
    version = ctx.version_new
    tag = "v#{version}"

    cond do
      ctx.skip_github_release ->
        :skip

      not has_executable?("gh") ->
        {:skip, "gh CLI not installed"}

      not github_repo?() ->
        {:skip, "not a GitHub repository"}

      ctx.dry_run ->
        info("Would create GitHub release: #{tag}")
        :ok

      true ->
        case System.cmd(
               "gh",
               ["release", "create", tag, "--title", "Release #{tag}", "--generate-notes"],
               stderr_to_stdout: true
             ) do
          {_, 0} -> :ok
          {error, _} -> {:error, "gh release failed: #{String.trim(error)}"}
        end
    end
  end

  defp github_repo? do
    match?({_, 0}, System.cmd("gh", ["repo", "view", "--json", "name"], stderr_to_stdout: true))
  end
end
