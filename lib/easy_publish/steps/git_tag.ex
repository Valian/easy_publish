defmodule EasyPublish.Steps.GitTag do
  @moduledoc """
  Creates an annotated git tag for the release.
  """

  use EasyPublish.Step, name: "Creating git tag"

  @impl true
  def run(ctx) do
    version = ctx.version_new
    tag = "v#{version}"

    if ctx.dry_run do
      info("Would create tag: #{tag}")
      :ok
    else
      case git(["tag", "-a", tag, "-m", "Release #{tag}"]) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
