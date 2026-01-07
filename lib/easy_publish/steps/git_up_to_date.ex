defmodule EasyPublish.Steps.GitUpToDate do
  @moduledoc """
  Checks that the local branch is up to date with the remote.
  """

  use EasyPublish.Step, name: "Git is up to date with remote"

  @impl true
  def options do
    [{:skip_git, type: :boolean, default: false, doc: "Skip all git checks"}]
  end

  @impl true
  def check(ctx) do
    if ctx.skip_git do
      :skip
    else
      with {:ok, _} <- git(["fetch"]),
           {:ok, status} <- git(["status", "-uno"]) do
        cond do
          String.contains?(status, "Your branch is behind") ->
            {:error, "branch is behind remote"}

          String.contains?(status, "Your branch is ahead") ->
            {:error, "unpushed commits"}

          String.contains?(status, "have diverged") ->
            {:error, "branch has diverged from remote"}

          true ->
            :ok
        end
      else
        {:error, reason} -> {:error, "git error: #{reason}"}
      end
    end
  end
end
