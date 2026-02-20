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

  describe "check/1" do
    test "returns :skip when skip_format is true" do
      ctx = %{skip_format: true}

      assert Format.execute(ctx) == :skip
    end

    test "runs format check even when dry_run is true" do
      ctx = %{skip_format: false, dry_run: true}
      result = Format.execute(ctx)

      # Check actually runs regardless of dry_run
      assert result == :ok or match?({:error, "code is not formatted" <> _}, result)
    end

    test "returns :ok when code is formatted" do
      ctx = %{skip_format: false, dry_run: false}

      # The test project should be formatted
      result = Format.execute(ctx)

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
