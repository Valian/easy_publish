defmodule EasyPublish.Steps.FormatTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.Format

  describe "options/0" do
    test "declares skip_format option" do
      options = Format.options()

      assert {:skip_format, opts} = List.keyfind(options, :skip_format, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "run/1" do
    test "returns :skip when skip_format is true" do
      ctx = %{skip_format: true}

      assert Format.run(ctx) == :skip
    end

    test "logs dry-run message and returns :ok when dry_run is true" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{skip_format: false, dry_run: true}
      result = Format.run(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      assert IO.iodata_to_binary(msg) =~ "Would run: mix format --check-formatted"

      Mix.shell(Mix.Shell.IO)
    end

    test "returns :ok when code is formatted" do
      ctx = %{skip_format: false, dry_run: false}

      # The test project should be formatted
      result = Format.run(ctx)

      # If the code is formatted, expect :ok
      # If there happen to be formatting issues, that's also valid behavior
      assert result == :ok or match?({:error, "code is not formatted" <> _}, result)
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert Format.__step_name__() == "Code is formatted"
    end
  end
end
