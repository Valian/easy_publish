defmodule Mix.Tasks.EasyPublish.Release do
  @shortdoc "Run pre-release checks and publish to Hex"
  @moduledoc """
  A complete release tool for Hex packages. Runs checks, updates versions,
  changelog, commits, tags, pushes, and publishes to Hex.

  ## Usage

      mix easy_publish.release VERSION [options]

  VERSION can be:
    * `major` - Bump major version (1.2.3 -> 2.0.0)
    * `minor` - Bump minor version (1.2.3 -> 1.3.0)
    * `patch` - Bump patch version (1.2.3 -> 1.2.4)
    * `current` - Release the current version as-is (useful for initial release)
    * Explicit version like `2.0.0`

  By default, performs the full release. Use `--dry-run` to only run checks.

  ## Release Flow

  1. **Version Update** - Updates version in:
     - `mix.exs` (@version attribute)
     - `README.md` (dependency declaration)

  2. **Checks** - Validates everything is ready:
     - Git working directory is clean
     - On correct branch (default: main)
     - Git is up to date with remote
     - Tests pass
     - Code is formatted
     - Credo passes (if installed)
     - Dialyzer passes (if installed)
     - UNRELEASED section exists in changelog
     - `hex.build` succeeds (validates package)

  3. **Release**:
     - Updates changelog: replaces UNRELEASED with version and date
     - Commits all version changes
     - Creates git tag (vX.Y.Z)
     - Pushes commit and tag to remote
     - Creates GitHub release (if gh CLI available)
     - Publishes to Hex

  ## Options

    * `--dry-run` - Only run checks, don't make any changes
    * `--skip-tests` - Skip running tests
    * `--skip-format` - Skip format check
    * `--skip-credo` - Skip credo analysis
    * `--skip-dialyzer` - Skip dialyzer
    * `--skip-changelog` - Skip changelog check
    * `--skip-git` - Skip all git checks
    * `--skip-hex-dry-run` - Skip hex.publish --dry-run check
    * `--skip-github-release` - Skip GitHub release creation
    * `--branch NAME` - Required branch name (default: "main")

  ## Configuration

  Configure defaults in your `config/config.exs`:

      config :easy_publish,
        branch: "main",
        skip_tests: false,
        skip_format: false,
        skip_credo: false,
        skip_dialyzer: false,
        skip_changelog: false,
        skip_git: false,
        skip_hex_dry_run: false,
        skip_github_release: false,
        changelog_file: "CHANGELOG.md"

  CLI flags always override configuration.

  ## Changelog Format

  Your changelog should have an UNRELEASED section that will be replaced:

      # Changelog

      ## UNRELEASED

      - Added new feature
      - Fixed bug

      ## 0.1.0 - 2024-01-15

      - Initial release

  When releasing version 0.2.0, the UNRELEASED section becomes:

      ## 0.2.0 - 2024-01-20

  """

  use Mix.Task

  @requirements ["app.config"]

  @switches [
    dry_run: :boolean,
    skip_tests: :boolean,
    skip_format: :boolean,
    skip_credo: :boolean,
    skip_dialyzer: :boolean,
    skip_changelog: :boolean,
    skip_git: :boolean,
    skip_hex_dry_run: :boolean,
    skip_github_release: :boolean,
    branch: :string
  ]

  @default_config %{
    branch: "main",
    skip_tests: false,
    skip_format: false,
    skip_credo: false,
    skip_dialyzer: false,
    skip_changelog: false,
    skip_git: false,
    skip_hex_dry_run: false,
    skip_github_release: false,
    changelog_file: "CHANGELOG.md"
  }

  @impl Mix.Task
  def run(args) do
    {opts, rest} = OptionParser.parse!(args, strict: @switches)
    config = build_config(opts)
    current_version = Mix.Project.config()[:version]

    case parse_version_arg(rest, current_version) do
      {:ok, new_version} ->
        do_release(config, current_version, new_version)

      {:error, reason} ->
        Mix.shell().error(reason)
        Mix.shell().info("")
        Mix.shell().info("Usage: mix easy_publish.release VERSION [options]")
        Mix.shell().info("")
        Mix.shell().info("VERSION can be:")
        Mix.shell().info("  major   - Bump major version (1.2.3 -> 2.0.0)")
        Mix.shell().info("  minor   - Bump minor version (1.2.3 -> 1.3.0)")
        Mix.shell().info("  patch   - Bump patch version (1.2.3 -> 1.2.4)")
        Mix.shell().info("  current - Release current version as-is (for initial release)")
        Mix.shell().info("  X.Y.Z   - Explicit version (e.g., 2.0.0)")
        exit({:shutdown, 1})
    end
  end

  defp do_release(config, current_version, new_version) do
    Mix.shell().info([:cyan, "EasyPublish Release", :reset])
    Mix.shell().info([:cyan, "===================", :reset])
    Mix.shell().info("")

    Mix.shell().info([
      "Version: ",
      :yellow,
      current_version,
      :reset,
      " → ",
      :green,
      new_version,
      :reset
    ])

    Mix.shell().info("")

    cond do
      config.dry_run ->
        Mix.shell().info([
          :yellow,
          "DRY RUN - only running checks, no files will be modified",
          :reset
        ])

        Mix.shell().info("")

      current_version == new_version ->
        # "current" was used - no version updates needed
        Mix.shell().info([:yellow, "Releasing current version (no file updates needed)", :reset])
        Mix.shell().info("")

      true ->
        # Phase 1: Update version in files
        Mix.shell().info([:cyan, "Phase 1: Version Updates", :reset])
        Mix.shell().info("")

        case update_version_files(new_version, current_version) do
          :ok ->
            Mix.shell().info("")

          {:error, reason} ->
            Mix.shell().error("Failed to update version files: #{reason}")
            exit({:shutdown, 1})
        end
    end

    # Phase 1: Checks (now Phase 2)
    phase_num = if config.dry_run, do: "1", else: "2"
    Mix.shell().info([:cyan, "Phase #{phase_num}: Pre-release Checks", :reset])
    Mix.shell().info("")

    checks = [
      {:git_clean, "Git working directory is clean", &check_git_clean/1, config.skip_git},
      {:git_branch, "On #{config.branch} branch", &check_git_branch/1, config.skip_git},
      {:git_up_to_date, "Git is up to date with remote", &check_git_up_to_date/1,
       config.skip_git},
      {:tests, "Tests pass", &check_tests/1, config.skip_tests},
      {:format, "Code is formatted", &check_format/1, config.skip_format},
      {:credo, "Credo analysis passes", &check_credo/1, config.skip_credo},
      {:dialyzer, "Dialyzer passes", &check_dialyzer/1, config.skip_dialyzer},
      {:changelog, "Changelog has UNRELEASED section", &check_changelog_unreleased/1,
       config.skip_changelog},
      {:hex_dry_run, "Hex package builds successfully", &check_hex_dry_run/1,
       config.skip_hex_dry_run}
    ]

    results =
      Enum.map(checks, fn {name, description, check_fn, skip} ->
        run_check(name, description, check_fn, config, skip)
      end)

    failed = Enum.filter(results, fn {_, status, _} -> status == :failed end)
    skipped = Enum.filter(results, fn {_, status, _} -> status == :skipped end)
    passed = Enum.filter(results, fn {_, status, _} -> status == :passed end)

    Mix.shell().info("")

    Mix.shell().info([
      :green,
      "Passed: #{length(passed)}",
      :reset,
      "  ",
      :yellow,
      "Skipped: #{length(skipped)}",
      :reset,
      "  ",
      :red,
      "Failed: #{length(failed)}",
      :reset
    ])

    Mix.shell().info("")

    if length(failed) > 0 do
      Mix.shell().error("Pre-release checks failed. Fix the issues above before releasing.")
      exit({:shutdown, 1})
    end

    # Phase 3: Release (unless --dry-run)
    if config.dry_run do
      Mix.shell().info([:green, "All checks passed!", :reset])
      Mix.shell().info("Run without --dry-run to perform the release.")
    else
      Mix.shell().info([:cyan, "Phase 3: Release", :reset])
      Mix.shell().info("")

      release_steps(config, new_version)
    end
  end

  defp release_steps(config, version) do
    # Build steps dynamically based on config
    base_steps = [
      {"Updating changelog", &update_changelog/2},
      {"Committing release v#{version}", &commit_release/2},
      {"Creating git tag v#{version}", &create_tag/2},
      {"Pushing to remote", &push_to_remote/2}
    ]

    github_step =
      if config.skip_github_release do
        []
      else
        [{"Creating GitHub release", &create_github_release/2}]
      end

    hex_step = [{"Publishing to Hex", &publish_to_hex/2}]

    steps = base_steps ++ github_step ++ hex_step

    Enum.reduce_while(steps, :ok, fn {description, step_fn}, _acc ->
      Mix.shell().info([:cyan, "→ ", :reset, description, "..."])

      case step_fn.(config, version) do
        :ok ->
          Mix.shell().info([:green, "  ✓ Done", :reset])
          {:cont, :ok}

        :skip ->
          Mix.shell().info([:yellow, "  ○ Skipped", :reset])
          {:cont, :ok}

        {:error, reason} ->
          Mix.shell().error("  ✗ Failed: #{reason}")
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok ->
        Mix.shell().info("")
        Mix.shell().info([:green, "Successfully released v#{version}!", :reset])

      {:error, _} ->
        Mix.shell().info("")
        Mix.shell().error("Release failed!")
        exit({:shutdown, 1})
    end
  end

  defp build_config(opts) do
    app_config =
      Enum.reduce(@default_config, %{}, fn {key, default}, acc ->
        value = Application.get_env(:easy_publish, key, default)
        Map.put(acc, key, value)
      end)

    Enum.reduce(opts, app_config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  # Version parsing and calculation

  defp parse_version_arg([], _current) do
    {:error, "VERSION argument is required"}
  end

  defp parse_version_arg([version_arg | _], current_version) do
    case version_arg do
      "major" -> calculate_new_version(current_version, :major)
      "minor" -> calculate_new_version(current_version, :minor)
      "patch" -> calculate_new_version(current_version, :patch)
      "current" -> {:ok, current_version}
      explicit -> validate_explicit_version(explicit, current_version)
    end
  end

  defp calculate_new_version(current, bump_type) do
    case Version.parse(current) do
      {:ok, %Version{major: major, minor: minor, patch: patch}} ->
        new_version =
          case bump_type do
            :major -> "#{major + 1}.0.0"
            :minor -> "#{major}.#{minor + 1}.0"
            :patch -> "#{major}.#{minor}.#{patch + 1}"
          end

        {:ok, new_version}

      :error ->
        {:error, "cannot parse current version '#{current}' as semver"}
    end
  end

  defp validate_explicit_version(version, current_version) do
    with {:ok, new} <- Version.parse(version),
         {:ok, current} <- Version.parse(current_version) do
      case Version.compare(new, current) do
        :gt ->
          {:ok, version}

        :eq ->
          {:error, "new version #{version} is the same as current version"}

        :lt ->
          {:error,
           "new version #{version} must be greater than current version #{current_version}"}
      end
    else
      :error ->
        {:error, "invalid version format '#{version}', expected semver (e.g., 1.2.3)"}
    end
  end

  # Version file updates

  defp update_version_files(new_version, current_version) do
    with :ok <- update_mix_exs(new_version, current_version),
         :ok <- update_readme(new_version, current_version) do
      :ok
    end
  end

  defp update_mix_exs(new_version, current_version) do
    path = "mix.exs"

    if File.exists?(path) do
      content = File.read!(path)

      # Match @version "X.Y.Z" pattern
      updated =
        Regex.replace(
          ~r/@version\s+"#{Regex.escape(current_version)}"/,
          content,
          "@version \"#{new_version}\""
        )

      if updated == content do
        {:error, "could not find @version \"#{current_version}\" in mix.exs"}
      else
        File.write!(path, updated)
        Mix.shell().info([:green, "✓ ", :reset, "Updated mix.exs"])
        :ok
      end
    else
      {:error, "mix.exs not found"}
    end
  end

  defp update_readme(new_version, current_version) do
    path = "README.md"

    if File.exists?(path) do
      content = File.read!(path)

      # Extract major.minor for ~> format
      {new_major, new_minor} = extract_major_minor(new_version)
      {cur_major, cur_minor} = extract_major_minor(current_version)

      # Match {:package_name, "~> X.Y"} pattern
      # Use flexible pattern that matches any package name
      updated =
        Regex.replace(
          ~r/(\{:\w+,\s*"~>\s*)#{cur_major}\.#{cur_minor}(")/,
          content,
          "\\g{1}#{new_major}.#{new_minor}\\g{2}"
        )

      if updated == content do
        # Not an error - README might not have dependency version
        Mix.shell().info([
          :yellow,
          "○ ",
          :reset,
          "README.md - no dependency version found (skipped)"
        ])

        :ok
      else
        File.write!(path, updated)
        Mix.shell().info([:green, "✓ ", :reset, "Updated README.md"])
        :ok
      end
    else
      # README is optional
      Mix.shell().info([:yellow, "○ ", :reset, "README.md not found (skipped)"])
      :ok
    end
  end

  defp extract_major_minor(version) do
    case Version.parse(version) do
      {:ok, %Version{major: major, minor: minor}} -> {major, minor}
      :error -> {0, 0}
    end
  end

  defp run_check(name, description, check_fn, config, skip) do
    if skip do
      print_status(description, :skipped)
      {name, :skipped, nil}
    else
      case check_fn.(config) do
        :ok ->
          print_status(description, :passed)
          {name, :passed, nil}

        {:ok, _} ->
          print_status(description, :passed)
          {name, :passed, nil}

        :skip ->
          print_status(description, :skipped, "not available")
          {name, :skipped, nil}

        {:error, reason} ->
          print_status(description, :failed, reason)
          {name, :failed, reason}
      end
    end
  end

  defp print_status(description, status, detail \\ nil) do
    {symbol, color} =
      case status do
        :passed -> {"✓", :green}
        :failed -> {"✗", :red}
        :skipped -> {"○", :yellow}
      end

    detail_str = if detail, do: " (#{detail})", else: ""
    Mix.shell().info([color, "#{symbol} #{description}#{detail_str}", :reset])
  end

  # Git checks

  defp check_git_clean(_config) do
    case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
      {"", 0} -> :ok
      {output, 0} -> {:error, "uncommitted changes:\n#{String.trim(output)}"}
      {error, _} -> {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_git_branch(config) do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} ->
        branch = String.trim(branch)

        if branch == config.branch do
          :ok
        else
          {:error, "on branch '#{branch}', expected '#{config.branch}'"}
        end

      {error, _} ->
        {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_git_up_to_date(_config) do
    with {_, 0} <- System.cmd("git", ["fetch"], stderr_to_stdout: true),
         {status, 0} <- System.cmd("git", ["status", "-uno"], stderr_to_stdout: true) do
      cond do
        String.contains?(status, "Your branch is behind") ->
          {:error, "branch is behind remote"}

        String.contains?(status, "Your branch is ahead") ->
          {:error, "branch is ahead of remote (unpushed commits)"}

        String.contains?(status, "have diverged") ->
          {:error, "branch has diverged from remote"}

        true ->
          :ok
      end
    else
      {error, _} -> {:error, "git error: #{String.trim(error)}"}
    end
  end

  # Code quality checks

  defp check_tests(_config) do
    case System.cmd("mix", ["test"], stderr_to_stdout: true, env: [{"MIX_ENV", "test"}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, "tests failed\n#{last_lines(output, 5)}"}
    end
  end

  defp check_format(_config) do
    case System.cmd("mix", ["format", "--check-formatted"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, _} -> {:error, "code is not formatted, run: mix format"}
    end
  end

  defp check_credo(_config) do
    if has_dep?(:credo) do
      case System.cmd("mix", ["credo", "--strict"], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "credo issues found\n#{last_lines(output, 5)}"}
      end
    else
      :skip
    end
  end

  defp check_dialyzer(_config) do
    if has_dep?(:dialyxir) do
      case System.cmd("mix", ["dialyzer"], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "dialyzer errors\n#{last_lines(output, 5)}"}
      end
    else
      :skip
    end
  end

  # Changelog check - looks for UNRELEASED section

  defp check_changelog_unreleased(config) do
    changelog_file = config.changelog_file

    if File.exists?(changelog_file) do
      content = File.read!(changelog_file)

      if has_unreleased_section?(content) do
        :ok
      else
        {:error, "no UNRELEASED section found in #{changelog_file}"}
      end
    else
      {:error, "#{changelog_file} not found"}
    end
  end

  defp has_unreleased_section?(content) do
    content
    |> String.downcase()
    |> String.contains?("unreleased")
  end

  # Hex checks

  defp check_hex_dry_run(_config) do
    # Use hex.build instead of hex.publish --dry-run because dry-run still prompts for auth
    case System.cmd("mix", ["hex.build"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "error") or String.contains?(output, "Error") do
          {:error, "hex.build issues\n#{last_lines(output, 5)}"}
        else
          :ok
        end

      {output, _} ->
        {:error, "hex.build failed\n#{last_lines(output, 5)}"}
    end
  end

  # Release steps

  defp update_changelog(config, version) do
    changelog_file = config.changelog_file
    content = File.read!(changelog_file)
    date = Date.utc_today() |> Date.to_string()

    # Replace UNRELEASED with version and date (case insensitive)
    updated =
      Regex.replace(
        ~r/##\s*unreleased/i,
        content,
        "## #{version} - #{date}"
      )

    if updated == content do
      {:error, "failed to update UNRELEASED section"}
    else
      File.write!(changelog_file, updated)
      :ok
    end
  end

  defp commit_release(config, version) do
    changelog_file = config.changelog_file

    # Add all release-related files
    files_to_add = ["mix.exs", "README.md", changelog_file]

    Enum.each(files_to_add, fn file ->
      if File.exists?(file) do
        System.cmd("git", ["add", file], stderr_to_stdout: true)
      end
    end)

    case System.cmd("git", ["commit", "-m", "Release v#{version}"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp create_tag(_config, version) do
    tag = "v#{version}"

    case System.cmd("git", ["tag", "-a", tag, "-m", "Release #{tag}"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp push_to_remote(_config, version) do
    tag = "v#{version}"

    with {_, 0} <- System.cmd("git", ["push"], stderr_to_stdout: true),
         {_, 0} <- System.cmd("git", ["push", "origin", tag], stderr_to_stdout: true) do
      :ok
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp create_github_release(_config, version) do
    tag = "v#{version}"

    # Check if gh CLI is available
    case System.find_executable("gh") do
      nil ->
        Mix.shell().info("    (gh CLI not installed)")
        :skip

      _gh_path ->
        # Check if we're in a GitHub repo
        case System.cmd("gh", ["repo", "view", "--json", "name"], stderr_to_stdout: true) do
          {_, 0} ->
            # Create release with auto-generated notes from changelog
            case System.cmd(
                   "gh",
                   ["release", "create", tag, "--title", "Release #{tag}", "--generate-notes"],
                   stderr_to_stdout: true
                 ) do
              {_, 0} -> :ok
              {error, _} -> {:error, "gh release failed: #{String.trim(error)}"}
            end

          {_, _} ->
            Mix.shell().info("    (not a GitHub repository)")
            :skip
        end
    end
  end

  defp publish_to_hex(_config, _version) do
    # Use interactive mode for hex.publish to handle authentication prompts
    port =
      Port.open({:spawn_executable, System.find_executable("mix")}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: ["hex.publish", "--yes"]
      ])

    collect_port_output(port, "")
  end

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        collect_port_output(port, acc <> data)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, _code}} ->
        {:error, "hex.publish failed"}
    end
  end

  # Helpers

  defp has_dep?(dep) do
    Mix.Project.config()[:deps]
    |> Enum.any?(fn
      {^dep, _} -> true
      {^dep, _, _} -> true
      _ -> false
    end)
  end

  defp last_lines(string, n) do
    string
    |> String.split("\n")
    |> Enum.take(-n)
    |> Enum.join("\n")
  end
end
