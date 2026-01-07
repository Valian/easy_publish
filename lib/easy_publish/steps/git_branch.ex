defmodule EasyPublish.Steps.GitBranch do
  @moduledoc """
  Checks that the current branch matches the expected branch.
  """

  use EasyPublish.Step, name: "On correct branch"

  @impl true
  def options do
    [
      {:skip_git, type: :boolean, default: false, doc: "Skip all git checks"},
      {:branch, type: :string, default: "main", doc: "Required branch name"}
    ]
  end

  @impl true
  def check(ctx) do
    if ctx.skip_git do
      :skip
    else
      case git(["branch", "--show-current"]) do
        {:ok, branch} when branch == ctx.branch ->
          :ok

        {:ok, branch} ->
          {:error, "on '#{branch}', expected '#{ctx.branch}'"}

        {:error, reason} ->
          {:error, "git error: #{reason}"}
      end
    end
  end
end
