defmodule EasyPublish.Steps.HexPublishTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.HexPublish

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert HexPublish.__step_name__() == "Publishing to Hex"
    end
  end

  describe "run/1" do
    test "in dry_run mode logs the command and returns :ok" do
      Mix.shell(Mix.Shell.Process)

      try do
        ctx = %{dry_run: true}
        result = HexPublish.execute(ctx)

        assert result == :ok
        assert_receive {:mix_shell, :info, [msg]}
        assert IO.iodata_to_binary(msg) =~ "Would run: mix hex.publish --yes"
      after
        Mix.shell(Mix.Shell.IO)
      end
    end
  end
end
