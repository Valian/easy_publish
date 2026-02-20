defmodule EasyPublish.Steps.Format do
  @moduledoc """
  Checks that code is formatted.
  """

  use EasyPublish.Step, name: "Code is formatted"

  @impl true
  def options do
    [{:skip_format, type: :boolean, default: false, doc: "Skip format check"}]
  end

  @impl true
  def execute(ctx) do
    if ctx.skip_format do
      :skip
    else
      case run_mix_task("format", ["--check-formatted"]) do
        :ok -> :ok
        {:error, _} -> {:error, "code is not formatted, run: mix format"}
      end
    end
  end
end
