defmodule EasyPublish.Steps.GitCommit do
  @moduledoc """
  Commits the release changes (version files and changelog).
  """

  use EasyPublish.Step, name: "Committing release"

  @impl true
  def options do
    [{:changelog_file, type: :string, default: "CHANGELOG.md", doc: "Path to changelog file"}]
  end

  @impl true
  def execute(ctx) do
    version = ctx.version_new
    files = ["mix.exs", "README.md", ctx.changelog_file]

    if ctx.dry_run do
      info("Would commit: #{Enum.join(files, ", ")}")
      info("Message: Release v#{version}")
      :ok
    else
      files
      |> Enum.filter(&File.exists?/1)
      |> Enum.each(&git(["add", &1]))

      case git(["commit", "-m", "Release v#{version}"]) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
