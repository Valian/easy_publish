defmodule EasyPublish.Steps.UpdateChangelogTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.UpdateChangelog

  describe "options/0" do
    test "declares changelog_file option" do
      options = UpdateChangelog.options()

      assert {:changelog_file, opts} = List.keyfind(options, :changelog_file, 0)
      assert opts[:type] == :string
      assert opts[:default] == "CHANGELOG.md"
    end

    test "declares changelog_entry option" do
      options = UpdateChangelog.options()

      assert {:changelog_entry, opts} = List.keyfind(options, :changelog_entry, 0)
      assert opts[:type] == :string
      assert opts[:default] == nil
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert UpdateChangelog.__step_name__() == "Updating changelog"
    end
  end

  describe "run/1 in dry_run mode" do
    test "logs what would happen without changelog entry" do
      ctx = %{
        dry_run: true,
        version_new: "1.2.3",
        changelog_file: "CHANGELOG.md",
        changelog_entry: nil
      }

      assert :ok = UpdateChangelog.run(ctx)
    end

    test "logs what would happen with changelog entry" do
      ctx = %{
        dry_run: true,
        version_new: "1.2.3",
        changelog_file: "CHANGELOG.md",
        changelog_entry: "Fix critical bug"
      }

      assert :ok = UpdateChangelog.run(ctx)
    end
  end

  describe "run/1 - updating UNRELEASED" do
    test "replaces UNRELEASED with version and date" do
      temp_file = "test_changelog_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## UNRELEASED

        - Some change
        - Another change
        """)

        ctx = %{
          dry_run: false,
          version_new: "1.0.0",
          changelog_file: temp_file,
          changelog_entry: nil
        }

        assert :ok = UpdateChangelog.run(ctx)

        content = File.read!(temp_file)
        today = Date.utc_today() |> Date.to_string()
        assert content =~ "## 1.0.0 - #{today}"
        refute content =~ "UNRELEASED"
      after
        File.rm(temp_file)
      end
    end

    test "returns error when UNRELEASED section is missing" do
      temp_file = "test_changelog_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## 0.5.0 - 2025-01-01

        - Previous change
        """)

        ctx = %{
          dry_run: false,
          version_new: "1.0.0",
          changelog_file: temp_file,
          changelog_entry: nil
        }

        assert {:error, "failed to update UNRELEASED section"} = UpdateChangelog.run(ctx)
      after
        File.rm(temp_file)
      end
    end
  end

  describe "run/1 - adding changelog entry" do
    test "adds entry to existing UNRELEASED section" do
      temp_file = "test_changelog_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## UNRELEASED

        - Existing change
        """)

        ctx = %{
          dry_run: false,
          version_new: "1.0.0",
          changelog_file: temp_file,
          changelog_entry: "New feature added"
        }

        assert :ok = UpdateChangelog.run(ctx)

        content = File.read!(temp_file)
        assert content =~ "- New feature added"
        assert content =~ "- Existing change"
      after
        File.rm(temp_file)
      end
    end
  end
end
