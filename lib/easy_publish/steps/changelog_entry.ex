defmodule EasyPublish.Steps.ChangelogEntry do
  @moduledoc """
  Checks that the changelog has an UNRELEASED section.

  If `changelog_entry` option is provided, this check is skipped
  as the entry will be added automatically.
  """

  use EasyPublish.Step, name: "Changelog has UNRELEASED section"

  @impl true
  def options do
    [
      {:skip_changelog, type: :boolean, default: false, doc: "Skip changelog check"},
      {:changelog_file, type: :string, default: "CHANGELOG.md", doc: "Path to changelog file"},
      {:changelog_entry, type: :string, default: nil, doc: "Changelog entry to add automatically"}
    ]
  end

  @impl true
  def check(ctx) do
    cond do
      ctx.skip_changelog ->
        :skip

      ctx.changelog_entry != nil ->
        {:skip, "will be added automatically"}

      true ->
        case File.read(ctx.changelog_file) do
          {:ok, content} ->
            if has_unreleased?(content) do
              :ok
            else
              {:error, "no UNRELEASED section found"}
            end

          {:error, :enoent} ->
            {:error, "#{ctx.changelog_file} not found"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end
    end
  end

  defp has_unreleased?(content) do
    content |> String.downcase() |> String.contains?("unreleased")
  end
end
