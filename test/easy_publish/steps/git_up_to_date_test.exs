defmodule EasyPublish.Steps.GitUpToDateTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitUpToDate

  describe "options/0" do
    test "declares skip_git option" do
      options = GitUpToDate.options()

      assert {:skip_git, opts} = List.keyfind(options, :skip_git, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "check/1" do
    test "returns :skip when skip_git is true" do
      ctx = %{skip_git: true}

      assert GitUpToDate.check(ctx) == :skip
    end

    test "checks git status against remote" do
      ctx = %{skip_git: false}

      # This tests against real git state
      result = GitUpToDate.check(ctx)

      # The result depends on actual git state:
      # - :ok if up to date
      # - {:error, "branch is behind remote"} if behind
      # - {:error, "unpushed commits"} if ahead
      # - {:error, "branch has diverged from remote"} if diverged
      assert result == :ok or
               match?({:error, "branch is behind remote"}, result) or
               match?({:error, "unpushed commits"}, result) or
               match?({:error, "branch has diverged from remote"}, result) or
               match?({:error, "git error:" <> _}, result)
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitUpToDate.__step_name__() == "Git is up to date with remote"
    end
  end
end
