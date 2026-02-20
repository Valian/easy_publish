defmodule EasyPublish.Step.Helpers do
  @moduledoc """
  Helper functions available to all steps via `use EasyPublish.Step`.
  """

  @doc """
  Runs a mix task in the current process to properly inherit stdin.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  def run_mix_task(task, args \\ []) do
    Mix.Task.run(task, args)
    :ok
  rescue
    e in Mix.NoTaskError ->
      {:error, Exception.message(e)}

    e in Mix.Error ->
      {:error, Exception.message(e)}
  catch
    :exit, {:shutdown, 1} ->
      {:error, "#{task} failed"}
  end

  @doc """
  Runs a git command and returns the trimmed output.

  Returns `{:ok, output}` on success, `{:error, reason}` on failure.
  """
  def git(args) when is_list(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {error, _} -> {:error, String.trim(error)}
    end
  end

  @doc """
  Checks if a dependency is available in the project.
  """
  def has_dep?(dep) do
    Mix.Project.config()[:deps]
    |> Enum.any?(fn
      {^dep, _} -> true
      {^dep, _, _} -> true
      _ -> false
    end)
  end

  @doc """
  Checks if an executable is available on the system.
  """
  def has_executable?(name) do
    System.find_executable(name) != nil
  end

  @doc """
  Reloads the Mix project module from disk.

  After updating `mix.exs`, the in-memory module still has the old `@version`
  baked in. This purges the old module and recompiles `mix.exs` so that
  subsequent calls to `Mix.Project.config()` return the new version.
  """
  def reload_mix_project do
    module = Mix.Project.get!()
    Mix.Project.pop()
    :code.purge(module)
    :code.delete(module)
    Code.compile_file("mix.exs")
    :ok
  end

  @doc """
  Runs a mix task as a subprocess.

  Unlike `run_mix_task/2`, this starts a fresh BEAM with its own `MIX_ENV`,
  so project config is evaluated from scratch. Returns `:ok` on exit code 0,
  `{:error, reason}` otherwise.

  Output is streamed to stdout in real-time.

  ## Options

    * `:env` - Environment variables as a list of `{key, value}` tuples.
  """
  def run_mix_cmd(task, args \\ [], opts \\ []) do
    env = Keyword.get(opts, :env, [])

    case System.cmd("mix", [task | args], env: env, into: IO.stream(), stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, _} -> {:error, "mix #{task} failed"}
    end
  end

  @doc """
  Outputs an info message to the shell.
  """
  def info(msg), do: Mix.shell().info(msg)

  @doc """
  Outputs an error message to the shell.
  """
  def error(msg), do: Mix.shell().error(msg)

  @doc """
  Outputs a warning message to the shell (yellow).
  """
  def warn(msg), do: Mix.shell().info([:yellow, to_string(msg)])
end
