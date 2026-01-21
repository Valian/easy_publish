defmodule EasyPublish.Steps.GitClean do
  @moduledoc """
  Checks that the git working directory is clean (no uncommitted changes).
  """

  use EasyPublish.Step, name: "Git working directory is clean"

  @impl true
  def options do
    [{:skip_git, type: :boolean, default: false, doc: "Skip all git checks"}]
  end

  @impl true
  def execute(ctx) do
    if ctx.skip_git do
      :skip
    else
      case git(["status", "--porcelain"]) do
        {:ok, ""} -> :ok
        {:ok, output} -> {:error, "uncommitted changes:\n#{output}"}
        {:error, reason} -> {:error, "git error: #{reason}"}
      end
    end
  end
end
