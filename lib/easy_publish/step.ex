defmodule EasyPublish.Step do
  @moduledoc """
  Behaviour for release steps.

  ## Usage

      defmodule MyApp.Steps.CustomStep do
        use EasyPublish.Step, name: "Custom step"

        @impl true
        def options do
          [{:my_option, type: :string, default: "value", doc: "My custom option"}]
        end

        @impl true
        def execute(ctx) do
          if ctx.dry_run do
            info("Would do something")
            :ok
          else
            # Do the actual work
            :ok
          end
        end
      end

  ## Callbacks

  - `options/0` - (optional) Declare options this step uses
  - `execute/1` - Execute the step

  ## Return Values

  - `:ok` - Success, context unchanged
  - `{:ok, updated_ctx}` - Success with updated context for next steps
  - `:skip` - Step skipped (no reason)
  - `{:skip, reason}` - Step skipped with reason for display
  - `{:error, reason}` - Failure, halts pipeline
  """

  @type result ::
          :ok | {:ok, context()} | :skip | {:skip, reason :: term()} | {:error, reason :: term()}
  @type context :: map()
  @type option_def :: {atom(), keyword()}

  @callback options() :: [option_def()]
  @callback execute(context()) :: result()

  @optional_callbacks options: 0

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour EasyPublish.Step

      import EasyPublish.Step.Helpers

      @step_name Keyword.get_lazy(opts, :name, fn ->
                   __MODULE__
                   |> Module.split()
                   |> List.last()
                   |> Macro.underscore()
                   |> String.replace("_", " ")
                   |> String.capitalize()
                 end)

      def __step_name__, do: @step_name
    end
  end
end
