defmodule EasyPublish.Steps.GitCommitTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitCommit

  describe "options/0" do
    test "declares changelog_file option" do
      options = GitCommit.options()

      assert {:changelog_file, opts} = List.keyfind(options, :changelog_file, 0)
      assert opts[:type] == :string
      assert opts[:default] == "CHANGELOG.md"
    end
  end

  describe "run/1" do
    test "in dry_run mode logs what would be committed" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, version_new: "1.2.3", changelog_file: "CHANGELOG.md"}
      result = GitCommit.execute(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg1]}
      assert IO.iodata_to_binary(msg1) =~ "Would commit: mix.exs, README.md, CHANGELOG.md"
      assert_receive {:mix_shell, :info, [msg2]}
      assert IO.iodata_to_binary(msg2) =~ "Message: Release v1.2.3"

      Mix.shell(Mix.Shell.IO)
    end

    test "in dry_run mode uses custom changelog_file from context" do
      Mix.shell(Mix.Shell.Process)

      ctx = %{dry_run: true, version_new: "2.0.0", changelog_file: "HISTORY.md"}
      result = GitCommit.execute(ctx)

      assert result == :ok
      assert_receive {:mix_shell, :info, [msg]}
      assert IO.iodata_to_binary(msg) =~ "Would commit: mix.exs, README.md, HISTORY.md"

      Mix.shell(Mix.Shell.IO)
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitCommit.__step_name__() == "Committing release"
    end
  end
end
