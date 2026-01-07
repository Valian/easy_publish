defmodule EasyPublish.Steps.HexPublish do
  @moduledoc """
  Publishes the package to Hex.

  For CI/automation, set the `HEX_API_KEY` environment variable to bypass
  interactive authentication.
  """

  use EasyPublish.Step, name: "Publishing to Hex"

  @impl true
  def run(ctx) do
    if ctx.dry_run do
      info("Would run: mix hex.publish --yes")
      :ok
    else
      run_mix_task("hex.publish", ["--yes"])
    end
  end
end
