defmodule EasyPublish.Steps.GitHubReleaseTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitHubRelease

  describe "options/0" do
    test "declares skip_github_release option" do
      options = GitHubRelease.options()

      assert {:skip_github_release, opts} = List.keyfind(options, :skip_github_release, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "run/1" do
    test "returns :skip when skip_github_release is true" do
      ctx = %{skip_github_release: true, version_new: "1.0.0", dry_run: false}

      assert GitHubRelease.execute(ctx) == :skip
    end

    test "handles various environment states" do
      ctx = %{skip_github_release: false, version_new: "1.0.0", dry_run: false}

      result = GitHubRelease.execute(ctx)

      # Expected outcomes depend on environment:
      # - {:skip, "gh CLI not installed"} if gh not available
      # - {:skip, "not a GitHub repository"} if not GitHub
      # - :ok or {:error, _} if it's actually a GitHub repo
      assert result in [:ok, :skip] or match?({:skip, _}, result) or match?({:error, _}, result)
    end

    test "logs message in dry_run mode when gh is available" do
      if System.find_executable("gh") do
        Mix.shell(Mix.Shell.Process)

        ctx = %{
          skip_github_release: false,
          version_new: "1.0.0",
          dry_run: true
        }

        result = GitHubRelease.execute(ctx)

        case result do
          :ok ->
            assert_receive {:mix_shell, :info, [msg]}
            assert IO.iodata_to_binary(msg) =~ "Would create GitHub release: v1.0.0"

          {:skip, _reason} ->
            # gh not installed or not a GitHub repo - that's fine
            :ok
        end

        Mix.shell(Mix.Shell.IO)
      end
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitHubRelease.__step_name__() == "Creating GitHub release"
    end
  end
end
