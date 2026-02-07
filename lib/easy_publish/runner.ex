defmodule EasyPublish.Runner do
  @moduledoc """
  Executes a pipeline of steps in sequence.

  The runner:
  1. Collects all option definitions from steps
  2. Validates provided options against registered options
  3. Applies defaults for missing options
  4. Executes each step's `execute/1` callback
  """

  # Core options that are always available (set by the release task, not steps)
  @core_options %{
    dry_run: [type: :boolean, default: false, doc: "Preview without making changes"],
    version_current: [type: :string, required: true, doc: "Current version"],
    version_new: [type: :string, required: true, doc: "New version to release"]
  }

  @doc """
  Collects all option definitions declared by the given steps.
  """
  def collect_options(steps) do
    steps
    |> Enum.flat_map(fn step ->
      Code.ensure_loaded!(step)
      if function_exported?(step, :options, 0), do: step.options(), else: []
    end)
    |> Map.new()
  end

  @doc """
  Runs a pipeline of steps with the given options.

  Returns `{:ok, final_context}` on success, `{:error, reason}` on failure.

  ## Options

    * `:extra_known_options` - Additional option definitions to accept during
      validation (e.g. from another pipeline), as a map of `%{key => meta}`.
  """
  def run(steps, opts, run_opts \\ []) do
    with {:ok, ctx} <- build_context(steps, opts, run_opts) do
      execute_steps(steps, ctx)
    end
  end

  defp build_context(steps, opts, run_opts) do
    step_options = collect_options(steps)
    all_options = Map.merge(@core_options, step_options)

    # For validation, also accept options from other pipelines (e.g. check + release)
    extra_options = Keyword.get(run_opts, :extra_known_options, %{})
    validation_options = Map.merge(all_options, extra_options)
    registered_keys = Map.keys(validation_options)

    provided_keys = Keyword.keys(opts)
    unknown = provided_keys -- registered_keys

    cond do
      unknown != [] ->
        [first | _] = unknown
        suggestion = find_similar(first, registered_keys)
        {:error, "unknown option :#{first}#{suggestion}"}

      true ->
        ctx =
          all_options
          |> Enum.map(fn {key, meta} -> {key, Keyword.get(meta, :default)} end)
          |> Keyword.merge(opts)
          |> Map.new()
          |> Map.put(:registered_options, all_options)

        missing =
          all_options
          |> Enum.filter(fn {key, meta} -> meta[:required] && is_nil(ctx[key]) end)
          |> Enum.map(fn {key, _} -> key end)

        if missing != [] do
          {:error, "missing required option(s): #{Enum.map_join(missing, ", ", &":#{&1}")}"}
        else
          {:ok, ctx}
        end
    end
  end

  defp execute_steps(steps, context) do
    Enum.reduce_while(steps, {:ok, context}, fn step, {:ok, ctx} ->
      step_name = get_step_name(step)
      print_step_start(step_name, ctx)

      result = step.execute(ctx)
      print_step_result(result)

      case result do
        :ok -> {:cont, {:ok, ctx}}
        {:ok, new_ctx} -> {:cont, {:ok, new_ctx}}
        :skip -> {:cont, {:ok, ctx}}
        {:skip, _reason} -> {:cont, {:ok, ctx}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp get_step_name(step) do
    if function_exported?(step, :__step_name__, 0) do
      step.__step_name__()
    else
      step
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.replace("_", " ")
      |> String.capitalize()
    end
  end

  defp print_step_start(name, ctx) do
    if ctx[:dry_run] do
      Mix.shell().info([:cyan, "→ ", :reset, name, " (dry run)..."])
    else
      Mix.shell().info([:cyan, "→ ", :reset, name, "..."])
    end
  end

  defp print_step_result(result) do
    case result do
      :ok -> Mix.shell().info([:green, "  ✓ Done"])
      {:ok, _} -> Mix.shell().info([:green, "  ✓ Done"])
      :skip -> Mix.shell().info([:yellow, "  ○ Skipped"])
      {:skip, reason} -> Mix.shell().info([:yellow, "  ○ Skipped: #{reason}"])
      {:error, reason} -> Mix.shell().error("  ✗ Failed: #{reason}")
    end
  end

  defp find_similar(unknown, registered_keys) do
    best =
      registered_keys
      |> Enum.map(fn key -> {key, String.jaro_distance(to_string(unknown), to_string(key))} end)
      |> Enum.max_by(fn {_, score} -> score end, fn -> {nil, 0} end)

    case best do
      {key, score} when score > 0.7 -> ". Did you mean :#{key}?"
      _ -> ""
    end
  end
end
