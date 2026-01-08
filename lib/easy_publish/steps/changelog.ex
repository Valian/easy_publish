defmodule EasyPublish.Steps.Changelog do
  @moduledoc """
  Handles changelog validation and updates.

  In the check phase:
  - Verifies the changelog has an UNRELEASED section (unless `changelog_entry` is provided)

  In the run phase:
  - Adds a changelog entry if provided via `changelog_entry` option
  - Replaces UNRELEASED with the version and date
  """

  use EasyPublish.Step, name: "Changelog"

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
        {:skip, "entry will be added automatically"}

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

  @impl true
  def run(ctx) do
    if ctx.skip_changelog do
      :skip
    else
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

    case File.write(path, updated) do
      :ok -> :ok
      {:error, reason} -> {:error, "#{path}: #{inspect(reason)}"}
    end
  end

  defp update_unreleased(path, version) do
    case File.read(path) do
      {:ok, content} ->
        date = Date.utc_today() |> Date.to_string()
        updated = Regex.replace(~r/##\s*unreleased/i, content, "## #{version} - #{date}")

        if updated == content do
          {:error, "failed to update UNRELEASED section"}
        else
          case File.write(path, updated) do
            :ok -> :ok
            {:error, reason} -> {:error, "#{path}: #{inspect(reason)}"}
          end
        end

      {:error, reason} ->
        {:error, "#{path}: #{inspect(reason)}"}
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
