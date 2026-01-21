defmodule EasyPublish.Steps.GitTagTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitTag

  describe "run/1" do
    test "logs correct message in dry_run mode" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, version_new: "1.0.0"}
      result = GitTag.execute(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      assert IO.iodata_to_binary(msg) =~ "Would create tag: v1.0.0"

      Mix.shell(Mix.Shell.IO)
    end

    test "logs correct message with different version in dry_run mode" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, version_new: "2.5.3"}
      result = GitTag.execute(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      assert IO.iodata_to_binary(msg) =~ "Would create tag: v2.5.3"

      Mix.shell(Mix.Shell.IO)
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitTag.__step_name__() == "Creating git tag"
    end
  end
end
