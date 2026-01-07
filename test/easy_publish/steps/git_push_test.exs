defmodule EasyPublish.Steps.GitPushTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitPush

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitPush.__step_name__() == "Pushing to remote"
    end
  end

  describe "run/1" do
    test "in dry_run mode logs would push message with tag" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, version_new: "1.2.3"}
      result = GitPush.run(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      output = IO.iodata_to_binary(msg)
      assert output =~ "Would push commit and tag v1.2.3 to remote"

      Mix.shell(Mix.Shell.IO)
    end

    test "in dry_run mode includes version in tag format" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, version_new: "0.5.0"}
      result = GitPush.run(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      output = IO.iodata_to_binary(msg)
      assert output =~ "v0.5.0"

      Mix.shell(Mix.Shell.IO)
    end
  end
end
