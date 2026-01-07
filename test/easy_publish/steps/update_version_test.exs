defmodule EasyPublish.Steps.UpdateVersionTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.UpdateVersion

  describe "run/1" do
    test "skips when releasing current version" do
      ctx = %{
        dry_run: false,
        version_current: "1.0.0",
        version_new: "1.0.0"
      }

      assert {:skip, "releasing current version"} = UpdateVersion.run(ctx)
    end

    test "logs what would be updated in dry_run mode" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{
        dry_run: true,
        version_current: "1.0.0",
        version_new: "1.0.1"
      }

      result = UpdateVersion.run(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg1]}
      assert IO.iodata_to_binary(msg1) =~ "Would update mix.exs: 1.0.0 -> 1.0.1"
      assert_receive {:mix_shell, :info, [msg2]}
      assert IO.iodata_to_binary(msg2) =~ "Would update README.md dependency version"

      Mix.shell(Mix.Shell.IO)
    end

    test "logs correct messages for different version bumps" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{
        dry_run: true,
        version_current: "1.0.0",
        version_new: "2.0.0"
      }

      result = UpdateVersion.run(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg1]}
      assert IO.iodata_to_binary(msg1) =~ "Would update mix.exs: 1.0.0 -> 2.0.0"

      Mix.shell(Mix.Shell.IO)
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert UpdateVersion.__step_name__() == "Updating version files"
    end
  end
end
