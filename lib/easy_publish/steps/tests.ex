defmodule EasyPublish.Steps.Tests do
  @moduledoc """
  Runs the test suite.
  """

  use EasyPublish.Step, name: "Tests pass"

  @impl true
  def options do
    [{:skip_tests, type: :boolean, default: false, doc: "Skip running tests"}]
  end

  @impl true
  def execute(ctx) do
    if ctx.skip_tests do
      :skip
    else
      case run_mix_cmd("test", [], env: [{"MIX_ENV", "test"}]) do
        :ok -> :ok
        {:error, _} -> {:error, "tests failed"}
      end
    end
  end
end
