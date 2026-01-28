defmodule EasyPublish.Steps.UpdateVersion do
  @moduledoc """
  Updates version in mix.exs and README.md.

  Skipped if current and new versions are the same (e.g., releasing current version).
  """

  use EasyPublish.Step, name: "Updating version files"

  @impl true
  def execute(ctx) do
    current = ctx.version_current
    new = ctx.version_new

    if current == new do
      {:skip, "releasing current version"}
    else
      if ctx.dry_run do
        info("Would update mix.exs: #{current} -> #{new}")
        info("Would update README.md dependency version")
        :ok
      else
        with :ok <- update_mix_exs(new, current),
             :ok <- update_readme(new, current) do
          :ok
        end
      end
    end
  end

  defp update_mix_exs(new_version, current_version) do
    path = "mix.exs"

    with {:ok, content} <- File.read(path),
         updated =
           Regex.replace(
             ~r/@version\s+"#{Regex.escape(current_version)}"/,
             content,
             "@version \"#{new_version}\""
           ),
         true <- updated != content,
         :ok <- File.write(path, updated) do
      :ok
    else
      {:error, reason} -> {:error, "mix.exs: #{inspect(reason)}"}
      false -> {:error, "could not find @version \"#{current_version}\" in mix.exs"}
    end
  end

  defp update_readme(new_version, current_version) do
    path = "README.md"

    case File.read(path) do
      {:ok, content} ->
        {new_major, new_minor} = extract_major_minor(new_version)
        {cur_major, cur_minor} = extract_major_minor(current_version)

        updated =
          Regex.replace(
            ~r/(\{:\w+,\s*"~>\s*)#{cur_major}\.#{cur_minor}(")/,
            content,
            "\\g{1}#{new_major}.#{new_minor}\\g{2}"
          )

        if updated != content do
          case File.write(path, updated) do
            :ok -> :ok
            {:error, reason} -> {:error, "README.md: #{inspect(reason)}"}
          end
        else
          :ok
        end

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        {:error, "README.md: #{inspect(reason)}"}
    end
  end

  defp extract_major_minor(version) do
    [major, minor | _] = String.split(version, ".")
    {major, minor}
  end
end
