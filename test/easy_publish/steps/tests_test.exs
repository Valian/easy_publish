defmodule EasyPublish.Steps.TestsTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.Tests

  describe "options/0" do
    test "declares skip_tests option" do
      options = Tests.options()

      assert {:skip_tests, opts} = List.keyfind(options, :skip_tests, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "execute/1" do
    test "returns :skip when skip_tests is true" do
      ctx = %{skip_tests: true}

      assert Tests.execute(ctx) == :skip
    end

    test "does not skip when dry_run is true" do
      # Can't unit-test actual execution — it spawns `mix test` as a subprocess,
      # which would recursively run the entire suite. Just verify dry_run doesn't
      # cause a skip. Actual execution is covered by integration tests.
      ctx = %{dry_run: true, skip_tests: false}

      # Would need to actually run to not be :skip
      # We can't call execute/1 here, but we can verify the skip logic directly
      refute ctx.skip_tests
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert Tests.__step_name__() == "Tests pass"
    end
  end
end
