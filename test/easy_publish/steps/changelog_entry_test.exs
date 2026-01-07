defmodule EasyPublish.Steps.ChangelogEntryTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.ChangelogEntry

  describe "options/0" do
    test "declares skip_changelog option" do
      options = ChangelogEntry.options()

      assert {:skip_changelog, opts} = List.keyfind(options, :skip_changelog, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end

    test "declares changelog_file option" do
      options = ChangelogEntry.options()

      assert {:changelog_file, opts} = List.keyfind(options, :changelog_file, 0)
      assert opts[:type] == :string
      assert opts[:default] == "CHANGELOG.md"
    end

    test "declares changelog_entry option" do
      options = ChangelogEntry.options()

      assert {:changelog_entry, opts} = List.keyfind(options, :changelog_entry, 0)
      assert opts[:type] == :string
      assert opts[:default] == nil
    end
  end

  describe "check/1" do
    test "returns :skip when skip_changelog is true" do
      ctx = %{skip_changelog: true, changelog_file: "CHANGELOG.md", changelog_entry: nil}

      assert ChangelogEntry.check(ctx) == :skip
    end

    test "returns skip with reason when changelog_entry is provided" do
      ctx = %{
        skip_changelog: false,
        changelog_file: "CHANGELOG.md",
        changelog_entry: "Some entry"
      }

      assert ChangelogEntry.check(ctx) == {:skip, "will be added automatically"}
    end

    test "returns error when changelog file doesn't exist" do
      nonexistent = "nonexistent_changelog_#{:rand.uniform(10000)}.md"

      ctx = %{
        skip_changelog: false,
        changelog_file: nonexistent,
        changelog_entry: nil
      }

      assert ChangelogEntry.check(ctx) == {:error, "#{nonexistent} not found"}
    end

    test "returns error when changelog has no UNRELEASED section" do
      test_file = "test_changelog_#{:rand.uniform(10000)}.md"

      try do
        File.write!(test_file, """
        # Changelog

        ## [1.0.0] - 2024-01-01

        - Initial release
        """)

        ctx = %{skip_changelog: false, changelog_file: test_file, changelog_entry: nil}

        assert ChangelogEntry.check(ctx) == {:error, "no UNRELEASED section found"}
      after
        File.rm(test_file)
      end
    end

    test "returns :ok when changelog has UNRELEASED section" do
      test_file = "test_changelog_#{:rand.uniform(10000)}.md"

      try do
        File.write!(test_file, """
        # Changelog

        ## UNRELEASED

        - Some changes
        """)

        ctx = %{skip_changelog: false, changelog_file: test_file, changelog_entry: nil}

        assert ChangelogEntry.check(ctx) == :ok
      after
        File.rm(test_file)
      end
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert ChangelogEntry.__step_name__() == "Changelog has UNRELEASED section"
    end
  end
end
