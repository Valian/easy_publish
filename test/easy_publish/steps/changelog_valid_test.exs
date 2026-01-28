defmodule EasyPublish.Steps.ChangelogValidTest do
  use ExUnit.Case, async: false

  alias EasyPublish.Steps.ChangelogValid

  describe "options/0" do
    test "declares skip_changelog option" do
      options = ChangelogValid.options()

      assert {:skip_changelog, opts} = List.keyfind(options, :skip_changelog, 0)
      assert opts[:type] == :boolean
      assert opts[:default] == false
    end

    test "declares changelog_file option" do
      options = ChangelogValid.options()

      assert {:changelog_file, opts} = List.keyfind(options, :changelog_file, 0)
      assert opts[:type] == :string
      assert opts[:default] == "CHANGELOG.md"
    end

    test "declares changelog_entry option" do
      options = ChangelogValid.options()

      assert {:changelog_entry, opts} = List.keyfind(options, :changelog_entry, 0)
      assert opts[:type] == :string
      assert opts[:default] == nil
    end
  end

  describe "__step_name__/0" do
    test "returns the configured step name" do
      assert ChangelogValid.__step_name__() == "Changelog has UNRELEASED section"
    end
  end

  describe "execute/1" do
    test "returns :skip when skip_changelog is true" do
      ctx = %{skip_changelog: true, changelog_file: "CHANGELOG.md", changelog_entry: nil}

      assert ChangelogValid.execute(ctx) == :skip
    end

    test "returns skip with reason when changelog_entry is provided" do
      ctx = %{skip_changelog: false, changelog_file: "CHANGELOG.md", changelog_entry: "Fix bug"}

      assert {:skip, "entry will be added automatically"} = ChangelogValid.execute(ctx)
    end

    test "returns :ok when UNRELEASED section exists" do
      temp_file = "test_changelog_valid_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## UNRELEASED

        - Some change
        """)

        ctx = %{skip_changelog: false, changelog_file: temp_file, changelog_entry: nil}

        assert :ok = ChangelogValid.execute(ctx)
      after
        File.rm(temp_file)
      end
    end

    test "returns error when UNRELEASED section is missing" do
      temp_file = "test_changelog_valid_#{:rand.uniform(10000)}.md"

      try do
        File.write!(temp_file, """
        # Changelog

        ## 0.5.0 - 2025-01-01

        - Previous change
        """)

        ctx = %{skip_changelog: false, changelog_file: temp_file, changelog_entry: nil}

        assert {:error, "no UNRELEASED section found"} = ChangelogValid.execute(ctx)
      after
        File.rm(temp_file)
      end
    end

    test "returns error when changelog file doesn't exist" do
      ctx = %{skip_changelog: false, changelog_file: "nonexistent.md", changelog_entry: nil}

      assert {:error, "nonexistent.md not found"} = ChangelogValid.execute(ctx)
    end
  end
end
