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
    cond do
      ctx.skip_hex_build ->
        :skip

      ctx.dry_run ->
        info("Would run: mix hex.build")
        :ok

      true ->
        case run_mix_task("hex.build") do
          :ok -> :ok
          {:error, _} -> {:error, "hex.build failed"}
        end
    end
  end
end
