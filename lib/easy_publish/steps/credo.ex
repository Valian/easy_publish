defmodule EasyPublish.Steps.Credo do
  @moduledoc """
  Runs credo analysis (if installed).
  """

  use EasyPublish.Step, name: "Credo analysis passes"

  @impl true
  def options do
    [{:skip_credo, type: :boolean, default: false, doc: "Skip credo analysis"}]
  end

  @impl true
  def run(ctx) do
    cond do
      ctx.skip_credo ->
        :skip

      not has_dep?(:credo) ->
        {:skip, "not installed"}

      ctx.dry_run ->
        info("Would run: mix credo --strict")
        :ok

      true ->
        case run_mix_task("credo", ["--strict"]) do
          :ok -> :ok
          {:error, _} -> {:error, "credo issues found"}
        end
    end
  end
end
