defmodule EasyPublish.Steps.ChangelogTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.Changelog

  describe "options/0" do
    test "declares skip_changelog option" do
      options = Changelog.options()

      assert {:skip_changelog, opts} = List.keyfind(options, :skip_changelog, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end

    test "declares changelog_file option" do
      options = Changelog.options()

      assert {:changelog_file, opts} = List.keyfind(options, :changelog_file, 0)
      assert opts[:type] == :string
      assert opts[:default] == "CHANGELOG.md"
    end

    test "declares changelog_entry option" do
      options = Changelog.options()

      assert {:changelog_entry, opts} = List.keyfind(options, :changelog_entry, 0)
      assert opts[:type] == :string
      assert opts[:default] == nil
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert Changelog.__step_name__() == "Changelog"
    end
  end

  describe "check/1" do
    test "returns :skip when skip_changelog is true" do
      ctx = %{skip_changelog: true, changelog_file: "CHANGELOG.md", changelog_entry: nil}

      assert Changelog.check(ctx) == :skip
    end

    test "returns skip with reason when changelog_entry is provided" do
      ctx = %{skip_changelog: false, changelog_file: "CHANGELOG.md", changelog_entry: "Fix bug"}

      assert {:skip, "entry will be added automatically"} = Changelog.check(ctx)
    end

    test "returns :ok when UNRELEASED section exists" do
      temp_file = "test_changelog_check_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## UNRELEASED

        - Some change
        """)

        ctx = %{skip_changelog: false, changelog_file: temp_file, changelog_entry: nil}

        assert :ok = Changelog.check(ctx)
      after
        File.rm(temp_file)
      end
    end

    test "returns error when UNRELEASED section is missing" do
      temp_file = "test_changelog_check_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## 0.5.0 - 2025-01-01

        - Previous change
        """)

        ctx = %{skip_changelog: false, changelog_file: temp_file, changelog_entry: nil}

        assert {:error, "no UNRELEASED section found"} = Changelog.check(ctx)
      after
        File.rm(temp_file)
      end
    end

    test "returns error when changelog file doesn't exist" do
      ctx = %{skip_changelog: false, changelog_file: "nonexistent.md", changelog_entry: nil}

      assert {:error, "nonexistent.md not found"} = Changelog.check(ctx)
    end
  end

  describe "run/1" do
    test "returns :skip when skip_changelog is true" do
      ctx = %{skip_changelog: true}

      assert Changelog.run(ctx) == :skip
    end

    test "logs what would happen in dry_run mode without changelog entry" do
      ctx = %{
        skip_changelog: false,
        dry_run: true,
        version_new: "1.2.3",
        changelog_file: "CHANGELOG.md",
        changelog_entry: nil
      }

      assert :ok = Changelog.run(ctx)
    end

    test "logs what would happen in dry_run mode with changelog entry" do
      ctx = %{
        skip_changelog: false,
        dry_run: true,
        version_new: "1.2.3",
        changelog_file: "CHANGELOG.md",
        changelog_entry: "Fix critical bug"
      }

      assert :ok = Changelog.run(ctx)
    end

    test "replaces UNRELEASED with version and date" do
      temp_file = "test_changelog_run_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## UNRELEASED

        - Some change
        - Another change
        """)

        ctx = %{
          skip_changelog: false,
          dry_run: false,
          version_new: "1.0.0",
          changelog_file: temp_file,
          changelog_entry: nil
        }

        assert :ok = Changelog.run(ctx)

        content = File.read!(temp_file)
        today = Date.utc_today() |> Date.to_string()
        assert content =~ "## 1.0.0 - #{today}"
        refute content =~ "UNRELEASED"
      after
        File.rm(temp_file)
      end
    end

    test "adds entry to existing UNRELEASED section" do
      temp_file = "test_changelog_run_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## UNRELEASED

        - Existing change
        """)

        ctx = %{
          skip_changelog: false,
          dry_run: false,
          version_new: "1.0.0",
          changelog_file: temp_file,
          changelog_entry: "New feature added"
        }

        assert :ok = Changelog.run(ctx)

        content = File.read!(temp_file)
        assert content =~ "- New feature added"
        assert content =~ "- Existing change"
      after
        File.rm(temp_file)
      end
    end

    test "returns error when UNRELEASED section is missing during run" do
      temp_file = "test_changelog_run_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## 0.5.0 - 2025-01-01

        - Previous change
        """)

        ctx = %{
          skip_changelog: false,
          dry_run: false,
          version_new: "1.0.0",
          changelog_file: temp_file,
          changelog_entry: nil
        }

        assert {:error, "failed to update UNRELEASED section"} = Changelog.run(ctx)
      after
        File.rm(temp_file)
      end
    end
  end
end
