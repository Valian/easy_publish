defmodule EasyPublish.Steps.HexBuild do
  @moduledoc """
  Validates the package builds successfully with hex.build.
  """

  use EasyPublish.Step, name: "Hex package builds successfully"

  @impl true
  def options do
    [{:skip_hex_build, type: :boolean, default: false, doc: "Skip hex.build validation"}]
  end

  @impl true
  def execute(ctx) do
    if ctx.skip_hex_build do
      :skip
    else
      case run_mix_task("hex.build") do
        :ok -> :ok
        {:error, _} -> {:error, "hex.build failed"}
      end
    end
  end
end
