defmodule Mix.Tasks.EasyPublish.ReleaseTest do
  use ExUnit.Case

  describe "argument parsing" do
    test "shows error when no version argument provided" do
      assert catch_exit(run_task([])) == {:shutdown, 1}
    end

    test "shows error for invalid version format" do
      assert catch_exit(run_task(["not.valid"])) == {:shutdown, 1}
    end

    test "shows error when new version equals current" do
      current = Mix.Project.config()[:version]
      assert catch_exit(run_task([current])) == {:shutdown, 1}
    end

    test "shows error when new version is less than current" do
      assert catch_exit(run_task(["0.0.1"])) == {:shutdown, 1}
    end
  end

  describe "dry-run mode" do
    test "runs checks without making changes" do
      # This test verifies dry-run mode starts properly
      # It will fail some checks (that's expected) but should show the dry-run banner
      output = run_and_capture(["patch", "--dry-run", "--skip-tests", "--skip-dialyzer"])

      assert output =~ "DRY RUN"
      assert output =~ "Pre-release Checks"
    end

    test "accepts major/minor/patch keywords" do
      current = Mix.Project.config()[:version]
      {:ok, current_parsed} = Version.parse(current)

      # Test that version calculation works correctly through the task
      output = run_and_capture(["patch", "--dry-run", "--skip-tests", "--skip-dialyzer"])

      expected_patch =
        "#{current_parsed.major}.#{current_parsed.minor}.#{current_parsed.patch + 1}"

      assert output =~ expected_patch
    end

    test "accepts current keyword for initial release" do
      current = Mix.Project.config()[:version]

      output = run_and_capture(["current", "--dry-run", "--skip-tests", "--skip-dialyzer"])

      # Should show current version (from -> to are the same)
      assert output =~ current
    end
  end

  describe "skip flags" do
    test "skip flags are accepted" do
      output =
        run_and_capture([
          "patch",
          "--dry-run",
          "--skip-tests",
          "--skip-format",
          "--skip-credo",
          "--skip-dialyzer",
          "--skip-changelog",
          "--skip-git",
          "--skip-hex-dry-run"
        ])

      # When skipped, checks show as skipped (○)
      assert output =~ "○"
    end

    test "branch option is accepted" do
      output =
        run_and_capture([
          "patch",
          "--dry-run",
          "--branch",
          "develop",
          "--skip-tests",
          "--skip-dialyzer"
        ])

      assert output =~ "develop"
    end
  end

  defp run_task(args) do
    Mix.Tasks.EasyPublish.Release.run(args)
  end

  defp run_and_capture(args) do
    Mix.shell(Mix.Shell.Process)

    try do
      run_task(args)
    catch
      :exit, _ -> :ok
    end

    collect_shell_output()
  after
    Mix.shell(Mix.Shell.IO)
  end

  defp collect_shell_output(acc \\ "") do
    receive do
      {:mix_shell, :info, [msg]} ->
        # Convert IO list to string
        text = IO.iodata_to_binary(msg)
        collect_shell_output(acc <> text <> "\n")

      {:mix_shell, :error, [msg]} ->
        text = IO.iodata_to_binary(msg)
        collect_shell_output(acc <> text <> "\n")
    after
      0 -> acc
    end
  end
end
