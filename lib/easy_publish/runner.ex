defmodule EasyPublish.Runner do
  @moduledoc """
  Orchestrates the release pipeline by running steps in sequence.

  The runner:
  1. Collects all option definitions from steps
  2. Validates provided options against registered options
  3. Applies defaults for missing options
  4. Runs the check phase on all steps
  5. Runs the run phase on all steps
  """

  # Core options that are always available (set by the release task, not steps)
  @core_options %{
    dry_run: [type: :boolean, default: false, doc: "Preview without making changes"],
    version_current: [type: :string, required: true, doc: "Current version"],
    version_new: [type: :string, required: true, doc: "New version to release"]
  }

  @doc """
  Runs the release pipeline with the given steps and options.

  Returns `{:ok, final_context}` on success, `{:error, reason}` on failure.
  """
  def run(steps, opts) do
    with {:ok, ctx} <- build_context(steps, opts),
         {:ok, ctx} <- run_phase(:check, steps, ctx),
         {:ok, ctx} <- run_phase(:run, steps, ctx) do
      {:ok, ctx}
    end
  end

  defp build_context(steps, opts) do
    step_options = collect_options(steps)
    all_options = Map.merge(@core_options, step_options)
    registered_keys = Map.keys(all_options)

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

  defp collect_options(steps) do
    all_options =
      steps
      |> Enum.flat_map(fn step ->
        Code.ensure_loaded!(step)
        if function_exported?(step, :options, 0), do: step.options(), else: []
      end)

    # Warn about duplicate options
    all_options
    |> Enum.map(fn {key, _} -> key end)
    |> Enum.frequencies()
    |> Enum.filter(fn {_, count} -> count > 1 end)
    |> Enum.each(fn {key, count} ->
      Mix.shell().info([
        :yellow,
        "Warning: option :#{key} is declared by #{count} steps"
      ])
    end)

    Map.new(all_options)
  end

  defp run_phase(phase, steps, context) do
    Enum.reduce_while(steps, {:ok, context}, fn step, {:ok, ctx} ->
      Code.ensure_loaded!(step)

      if function_exported?(step, phase, 1) do
        step_name = get_step_name(step)
        print_step_start(phase, step_name, ctx)

        result = apply(step, phase, [ctx])
        print_step_result(phase, step_name, result)

        case result do
          :ok -> {:cont, {:ok, ctx}}
          {:ok, new_ctx} -> {:cont, {:ok, new_ctx}}
          :skip -> {:cont, {:ok, ctx}}
          {:skip, _reason} -> {:cont, {:ok, ctx}}
          {:error, _} = err -> {:halt, err}
        end
      else
        {:cont, {:ok, ctx}}
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

  defp print_step_start(:check, _name, _ctx) do
    # Check results are printed with the result
    :ok
  end

  defp print_step_start(:run, name, ctx) do
    if ctx[:dry_run] do
      Mix.shell().info([:cyan, "→ ", :reset, name, " (dry run)..."])
    else
      Mix.shell().info([:cyan, "→ ", :reset, name, "..."])
    end
  end

  defp print_step_result(:check, name, result) do
    {symbol, color, detail} =
      case result do
        :ok -> {"✓", :green, nil}
        {:ok, _} -> {"✓", :green, nil}
        :skip -> {"○", :yellow, "skipped"}
        {:skip, reason} -> {"○", :yellow, reason}
        {:error, reason} -> {"✗", :red, reason}
      end

    suffix = if detail, do: " (#{detail})", else: ""
    Mix.shell().info([color, symbol, " ", :reset, name, suffix])
  end

  defp print_step_result(:run, _name, result) do
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
