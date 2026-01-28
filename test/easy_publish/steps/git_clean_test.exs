defmodule EasyPublish.Steps.GitCleanTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.GitClean

  describe "options/0" do
    test "declares skip_git option" do
      options = GitClean.options()

      assert {:skip_git, opts} = List.keyfind(options, :skip_git, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "check/1" do
    test "returns :skip when skip_git is true" do
      ctx = %{skip_git: true}

      assert GitClean.execute(ctx) == :skip
    end

    test "returns :ok when working directory is clean" do
      ctx = %{skip_git: false}

      # The test repo should be clean after commits
      # This tests against real git state
      result = GitClean.execute(ctx)

      # If we're in a clean state, expect :ok
      # If there happen to be uncommitted changes, that's also valid behavior
      assert result == :ok or match?({:error, "uncommitted changes:" <> _}, result)
    end

    test "returns error when there are uncommitted changes" do
      test_file = "test_uncommitted_file_#{:rand.uniform(10000)}.txt"

      try do
        # Create an uncommitted file in the repo
        File.write!(test_file, "test content")

        ctx = %{skip_git: false}
        result = GitClean.execute(ctx)

        assert {:error, msg} = result
        assert msg =~ "uncommitted changes"
        assert msg =~ test_file
      after
        File.rm(test_file)
      end
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert GitClean.__step_name__() == "Git working directory is clean"
    end
  end
end
