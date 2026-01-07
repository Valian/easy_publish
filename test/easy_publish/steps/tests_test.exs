defmodule EasyPublish.Steps.TestsTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.Tests

  describe "options/0" do
    test "declares skip_tests option" do
      options = Tests.options()

      assert {:skip_tests, opts} = List.keyfind(options, :skip_tests, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "run/1" do
    test "returns :skip when skip_tests is true" do
      ctx = %{skip_tests: true}

      assert Tests.run(ctx) == :skip
    end

    test "logs dry run message and returns :ok when dry_run is true" do
      Mix.shell(Mix.Shell.Process)

      try do
        ctx = %{dry_run: true, skip_tests: false}
        result = Tests.run(ctx)

        assert result == :ok
        assert_receive {:mix_shell, :info, [msg]}
        assert IO.iodata_to_binary(msg) =~ "Would run: mix test"
      after
        Mix.shell(Mix.Shell.IO)
      end
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert Tests.__step_name__() == "Tests pass"
    end
  end
end
