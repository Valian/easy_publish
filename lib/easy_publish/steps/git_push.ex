defmodule EasyPublish.Steps.GitPush do
  @moduledoc """
  Pushes the commit and tag to the remote.
  """

  use EasyPublish.Step, name: "Pushing to remote"

  @impl true
  def execute(ctx) do
    version = ctx.version_new
    tag = "v#{version}"

    if ctx.dry_run do
      info("Would push commit and tag #{tag} to remote")
      :ok
    else
      with {:ok, _} <- git(["push"]),
           {:ok, _} <- git(["push", "origin", tag]) do
        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
