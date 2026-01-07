defmodule EasyPublish.Steps.Dialyzer do
  @moduledoc """
  Runs dialyzer (if installed).
  """

  use EasyPublish.Step, name: "Dialyzer passes"

  @impl true
  def options do
    [{:skip_dialyzer, type: :boolean, default: false, doc: "Skip dialyzer"}]
  end

  @impl true
  def run(ctx) do
    cond do
      ctx.skip_dialyzer ->
        :skip

      not has_dep?(:dialyxir) ->
        {:skip, "not installed"}

      ctx.dry_run ->
        info("Would run: mix dialyzer")
        :ok

      true ->
        case run_mix_task("dialyzer") do
          :ok -> :ok
          {:error, _} -> {:error, "dialyzer errors"}
        end
    end
  end
end
