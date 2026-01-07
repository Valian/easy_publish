defmodule EasyPublish.Steps.GitBranchTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitBranch

  describe "options/0" do
    test "declares skip_git option" do
      options = GitBranch.options()

      assert {:skip_git, opts} = List.keyfind(options, :skip_git, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end

    test "declares branch option" do
      options = GitBranch.options()

      assert {:branch, opts} = List.keyfind(options, :branch, 0)
      assert opts[:type] == :string
      assert opts[:default] == "main"
    end
  end

  describe "check/1" do
    test "returns :skip when skip_git is true" do
      ctx = %{skip_git: true, branch: "main"}

      assert GitBranch.check(ctx) == :skip
    end

    test "returns :ok when on the expected branch" do
      {branch, 0} = System.cmd("git", ["branch", "--show-current"])
      current_branch = String.trim(branch)

      ctx = %{skip_git: false, branch: current_branch}

      assert GitBranch.check(ctx) == :ok
    end

    test "returns error when on wrong branch" do
      {branch, 0} = System.cmd("git", ["branch", "--show-current"])
      current_branch = String.trim(branch)

      wrong_branch = "definitely-not-#{current_branch}-branch"
      ctx = %{skip_git: false, branch: wrong_branch}

      result = GitBranch.check(ctx)

      assert {:error, msg} = result
      assert msg == "on '#{current_branch}', expected '#{wrong_branch}'"
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitBranch.__step_name__() == "On correct branch"
    end
  end
end
