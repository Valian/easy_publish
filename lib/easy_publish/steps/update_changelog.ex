defmodule EasyPublish.Steps.UpdateChangelog do
  @moduledoc """
  Updates the changelog by:
  1. Adding a changelog entry if provided via `changelog_entry` option
  2. Replacing UNRELEASED with the version and date
  """

  use EasyPublish.Step, name: "Updating changelog"

  @impl true
  def options do
    [
      {:changelog_file, type: :string, default: "CHANGELOG.md", doc: "Path to changelog file"},
      {:changelog_entry, type: :string, default: nil, doc: "Changelog entry to add automatically"}
    ]
  end

  @impl true
  def run(ctx) do
    version = ctx.version_new
    path = ctx.changelog_file

    if ctx.dry_run do
      if ctx.changelog_entry do
        info("Would add entry: #{ctx.changelog_entry}")
      end

      info("Would update UNRELEASED -> #{version} - #{Date.utc_today()}")
      :ok
    else
      with :ok <- maybe_add_entry(path, ctx.changelog_entry),
           :ok <- update_unreleased(path, version) do
        :ok
      end
    end
  end

  defp maybe_add_entry(_path, nil), do: :ok

  defp maybe_add_entry(path, entry) do
    content = read_or_create_changelog(path)

    updated =
      if has_unreleased?(content) do
        Regex.replace(~r/(##\s*unreleased\s*\n)/i, content, "\\1\n- #{entry}\n")
      else
        Regex.replace(~r/(#[^\n]*\n+)/, content, "\\1## UNRELEASED\n\n- #{entry}\n\n",
          global: false
        )
      end

    File.write!(path, updated)
    :ok
  rescue
    e in File.Error -> {:error, Exception.message(e)}
  end

  defp update_unreleased(path, version) do
    content = File.read!(path)
    date = Date.utc_today() |> Date.to_string()
    updated = Regex.replace(~r/##\s*unreleased/i, content, "## #{version} - #{date}")

    if updated == content do
      {:error, "failed to update UNRELEASED section"}
    else
      File.write!(path, updated)
      :ok
    end
  end

  defp read_or_create_changelog(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, :enoent} -> "# Changelog\n\n"
    end
  end

  defp has_unreleased?(content) do
    content |> String.downcase() |> String.contains?("unreleased")
  end
end
