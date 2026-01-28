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
    cond do
      ctx.skip_tests ->
        :skip

      ctx.dry_run ->
        info("Would run: mix test")
        :ok

      true ->
        original_env = Mix.env()
        Mix.env(:test)

        result = run_mix_task("test")

        Mix.env(original_env)

        case result do
          :ok -> :ok
          {:error, _} -> {:error, "tests failed"}
        end
    end
  end
end
