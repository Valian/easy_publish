defmodule EasyPublish.Steps.DialyzerTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.Dialyzer

  describe "options/0" do
    test "declares skip_dialyzer option" do
      options = Dialyzer.options()

      assert {:skip_dialyzer, opts} = List.keyfind(options, :skip_dialyzer, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end
  end

  describe "run/1" do
    test "returns :skip when skip_dialyzer is true" do
      ctx = %{skip_dialyzer: true}

      assert Dialyzer.run(ctx) == :skip
    end

    test "returns {:skip, reason} when dialyxir is not installed" do
      has_dialyxir? =
        Mix.Project.config()[:deps]
        |> Enum.any?(fn
          {:dialyxir, _} -> true
          {:dialyxir, _, _} -> true
          _ -> false
        end)

      if not has_dialyxir? do
        ctx = %{skip_dialyzer: false, dry_run: false}
        assert Dialyzer.run(ctx) == {:skip, "not installed"}
      end
    end

    test "logs message and returns :ok in dry_run mode when dialyxir installed" do
      has_dialyxir? =
        Mix.Project.config()[:deps]
        |> Enum.any?(fn
          {:dialyxir, _} -> true
          {:dialyxir, _, _} -> true
          _ -> false
        end)

      if has_dialyxir? do
        Mix.shell(Mix.Shell.Process)

        ctx = %{skip_dialyzer: false, dry_run: true}
        result = Dialyzer.run(ctx)

        assert result == :ok
        assert_receive {:mix_shell, :info, [msg]}
        assert IO.iodata_to_binary(msg) =~ "Would run: mix dialyzer"

        Mix.shell(Mix.Shell.IO)
      end
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert Dialyzer.__step_name__() == "Dialyzer passes"
    end
  end
end
