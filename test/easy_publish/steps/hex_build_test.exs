defmodule EasyPublish.Steps.HexBuildTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.HexBuild

  describe "options/0" do
    test "declares skip_hex_build option" do
      options = HexBuild.options()

      assert {:skip_hex_build, opts} = List.keyfind(options, :skip_hex_build, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "check/1" do
    test "returns :skip when skip_hex_build is true" do
      ctx = %{skip_hex_build: true, dry_run: false}

      assert HexBuild.check(ctx) == :skip
    end

    test "logs 'Would run: mix hex.build' in dry_run mode" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, skip_hex_build: false}
      result = HexBuild.check(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      assert IO.iodata_to_binary(msg) =~ "Would run: mix hex.build"

      Mix.shell(Mix.Shell.IO)
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert HexBuild.__step_name__() == "Hex package builds successfully"
    end
  end
end
