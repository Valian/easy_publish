defmodule EasyPublish.Steps.CredoTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.Credo

  describe "options/0" do
    test "declares skip_credo option" do
      options = Credo.options()

      assert {:skip_credo, opts} = List.keyfind(options, :skip_credo, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "check/1" do
    test "returns :skip when skip_credo is true" do
      ctx = %{skip_credo: true}

      assert Credo.check(ctx) == :skip
    end

    test "returns {:skip, reason} when credo is not installed" do
      has_credo? =
        Mix.Project.config()[:deps]
        |> Enum.any?(fn
          {:credo, _} -> true
          {:credo, _, _} -> true
          _ -> false
        end)

      if not has_credo? do
        ctx = %{skip_credo: false}
        assert Credo.check(ctx) == {:skip, "not installed"}
      end
    end

    test "logs message and returns :ok in dry_run mode" do
      has_credo? =
        Mix.Project.config()[:deps]
        |> Enum.any?(fn
          {:credo, _} -> true
          {:credo, _, _} -> true
          _ -> false
        end)

      # Only test dry_run if credo is installed (otherwise it skips first)
      if has_credo? do
        Mix.shell(Mix.Shell.Process)

        ctx = %{skip_credo: false, dry_run: true}
        result = Credo.check(ctx)

        assert result == :ok
        assert_receive {:mix_shell, :info, [msg]}
        assert IO.iodata_to_binary(msg) =~ "Would run: mix credo --strict"

        Mix.shell(Mix.Shell.IO)
      end
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert Credo.__step_name__() == "Credo analysis passes"
    end
  end
end
