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
    * `--changelog-entry CONTENT` - Add a changelog entry and skip UNRELEASED check

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
    branch: :string,
    changelog_entry: :string
  ]

  @default_config %{
    branch: "main",
    dry_run: false,
    skip_tests: false,
    skip_format: false,
    skip_credo: false,
    skip_dialyzer: false,
    skip_changelog: false,
    skip_git: false,
    skip_hex_dry_run: false,
    skip_github_release: false,
    changelog_file: "CHANGELOG.md",
    changelog_entry: nil
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
        print_usage()
        exit({:shutdown, 1})
    end
  end

  defp print_usage do
    Mix.shell().info("""

    Usage: mix easy_publish.release VERSION [options]

    VERSION can be:
      major   - Bump major version (1.2.3 -> 2.0.0)
      minor   - Bump minor version (1.2.3 -> 1.3.0)
      patch   - Bump patch version (1.2.3 -> 1.2.4)
      current - Release current version as-is (for initial release)
      X.Y.Z   - Explicit version (e.g., 2.0.0)
    """)
  end

  defp do_release(config, current_version, new_version) do
    print_header(current_version, new_version)

    config = maybe_add_changelog_entry(config)

    if config.dry_run do
      info([:yellow, "DRY RUN - only running checks, no files will be modified"])
      info("")
      run_checks_and_report(config)
      info([:green, "All checks passed!"])
      info("Run without --dry-run to perform the release.")
    else
      maybe_update_version_files(current_version, new_version)
      run_checks_and_report(config)
      run_release_steps(config, new_version)
    end
  end

  defp print_header(current_version, new_version) do
    info([:cyan, "EasyPublish Release"])
    info([:cyan, "==================="])
    info("")
    info(["Version: ", :yellow, current_version, :reset, " → ", :green, new_version])
    info("")
  end

  defp maybe_add_changelog_entry(config) do
    case config.changelog_entry do
      nil ->
        config

      entry ->
        case add_changelog_entry(config.changelog_file, entry) do
          :ok ->
            info([:green, "✓ ", :reset, "Added changelog entry"])
            info("")
            %{config | skip_changelog: true}

          {:error, reason} ->
            error("Failed to add changelog entry: #{reason}")
            exit({:shutdown, 1})
        end
    end
  end

  defp maybe_update_version_files(current, new) when current == new do
    info([:yellow, "Releasing current version (no file updates needed)"])
    info("")
  end

  defp maybe_update_version_files(current, new) do
    info([:cyan, "Updating Version Files"])
    info("")

    with :ok <- update_mix_exs(new, current),
         :ok <- update_readme(new, current) do
      info("")
    else
      {:error, reason} ->
        error("Failed to update version files: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp run_checks_and_report(config) do
    info([:cyan, "Pre-release Checks"])
    info("")

    results = run_all_checks(config)

    passed = Enum.count(results, &(&1 == :passed))
    skipped = Enum.count(results, &(&1 == :skipped))
    failed = Enum.count(results, &(&1 == :failed))

    info("")
    info([
      :green, "Passed: #{passed}", :reset, "  ",
      :yellow, "Skipped: #{skipped}", :reset, "  ",
      :red, "Failed: #{failed}"
    ])
    info("")

    if failed > 0 do
      error("Pre-release checks failed. Fix the issues above before releasing.")
      exit({:shutdown, 1})
    end
  end

  defp run_all_checks(config) do
    checks = [
      {"Git working directory is clean", &check_git_clean/0, config.skip_git},
      {"On #{config.branch} branch", fn -> check_git_branch(config.branch) end, config.skip_git},
      {"Git is up to date with remote", &check_git_up_to_date/0, config.skip_git},
      {"Tests pass", &check_tests/0, config.skip_tests},
      {"Code is formatted", &check_format/0, config.skip_format},
      {"Credo analysis passes", &check_credo/0, config.skip_credo},
      {"Dialyzer passes", &check_dialyzer/0, config.skip_dialyzer},
      {"Changelog has UNRELEASED section", fn -> check_changelog(config.changelog_file) end, config.skip_changelog},
      {"Hex package builds successfully", &check_hex_build/0, config.skip_hex_dry_run}
    ]

    Enum.map(checks, fn {desc, check_fn, skip} ->
      run_check(desc, check_fn, skip)
    end)
  end

  defp run_check(description, _check_fn, true) do
    print_check(description, :skipped)
    :skipped
  end

  defp run_check(description, check_fn, false) do
    case check_fn.() do
      :ok ->
        print_check(description, :passed)
        :passed

      :skip ->
        print_check(description, :skipped, "not available")
        :skipped

      {:error, reason} ->
        print_check(description, :failed, reason)
        :failed
    end
  end

  defp print_check(description, status, detail \\ nil) do
    {symbol, color} =
      case status do
        :passed -> {"✓", :green}
        :failed -> {"✗", :red}
        :skipped -> {"○", :yellow}
      end

    suffix = if detail, do: " (#{detail})", else: ""
    info([color, "#{symbol} #{description}#{suffix}"])
  end

  defp run_release_steps(config, version) do
    info([:cyan, "Release"])
    info("")

    steps = [
      {"Updating changelog", fn -> update_changelog(config.changelog_file, version) end},
      {"Committing release v#{version}", fn -> commit_release(config.changelog_file, version) end},
      {"Creating git tag v#{version}", fn -> create_tag(version) end},
      {"Pushing to remote", fn -> push_to_remote(version) end},
      {"Creating GitHub release", fn -> create_github_release(version) end, config.skip_github_release},
      {"Publishing to Hex", &publish_to_hex/0}
    ]

    Enum.reduce_while(steps, :ok, fn step, _acc ->
      {desc, step_fn, skip} = normalize_step(step)

      if skip do
        {:cont, :ok}
      else
        info([:cyan, "→ ", :reset, desc, "..."])

        case step_fn.() do
          :ok ->
            info([:green, "  ✓ Done"])
            {:cont, :ok}

          :skip ->
            info([:yellow, "  ○ Skipped"])
            {:cont, :ok}

          {:error, reason} ->
            error("  ✗ Failed: #{reason}")
            {:halt, :failed}
        end
      end
    end)
    |> case do
      :ok ->
        info("")
        info([:green, "Successfully released v#{version}!"])

      :failed ->
        info("")
        error("Release failed!")
        exit({:shutdown, 1})
    end
  end

  defp normalize_step({desc, fn_, skip}), do: {desc, fn_, skip}
  defp normalize_step({desc, fn_}), do: {desc, fn_, false}

  # Config

  defp build_config(opts) do
    @default_config
    |> Enum.reduce(%{}, fn {key, default}, acc ->
      Map.put(acc, key, Application.get_env(:easy_publish, key, default))
    end)
    |> Map.merge(Map.new(opts))
  end

  defp parse_version_arg([], _current), do: {:error, "VERSION argument is required"}
  defp parse_version_arg([arg | _], current), do: EasyPublish.Version.parse_arg(arg, current)

  # Version file updates

  defp update_mix_exs(new_version, current_version) do
    path = "mix.exs"

    with {:ok, content} <- File.read(path),
         updated = Regex.replace(
           ~r/@version\s+"#{Regex.escape(current_version)}"/,
           content,
           "@version \"#{new_version}\""
         ),
         true <- updated != content,
         :ok <- File.write(path, updated) do
      info([:green, "✓ ", :reset, "Updated mix.exs"])
      :ok
    else
      {:error, reason} -> {:error, "mix.exs: #{inspect(reason)}"}
      false -> {:error, "could not find @version \"#{current_version}\" in mix.exs"}
    end
  end

  defp update_readme(new_version, current_version) do
    path = "README.md"

    case File.read(path) do
      {:ok, content} ->
        {new_major, new_minor} = EasyPublish.Version.extract_major_minor(new_version)
        {cur_major, cur_minor} = EasyPublish.Version.extract_major_minor(current_version)

        updated =
          Regex.replace(
            ~r/(\{:\w+,\s*"~>\s*)#{cur_major}\.#{cur_minor}(")/,
            content,
            "\\g{1}#{new_major}.#{new_minor}\\g{2}"
          )

        if updated == content do
          info([:yellow, "○ ", :reset, "README.md - no dependency version found (skipped)"])
        else
          File.write!(path, updated)
          info([:green, "✓ ", :reset, "Updated README.md"])
        end

        :ok

      {:error, :enoent} ->
        info([:yellow, "○ ", :reset, "README.md not found (skipped)"])
        :ok

      {:error, reason} ->
        {:error, "README.md: #{inspect(reason)}"}
    end
  end

  # Checks

  defp check_git_clean do
    case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
      {"", 0} -> :ok
      {output, 0} -> {:error, "uncommitted changes:\n#{String.trim(output)}"}
      {error, _} -> {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_git_branch(expected) do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} ->
        branch = String.trim(branch)
        if branch == expected, do: :ok, else: {:error, "on '#{branch}', expected '#{expected}'"}

      {error, _} ->
        {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_git_up_to_date do
    with {_, 0} <- System.cmd("git", ["fetch"], stderr_to_stdout: true),
         {status, 0} <- System.cmd("git", ["status", "-uno"], stderr_to_stdout: true) do
      cond do
        String.contains?(status, "Your branch is behind") -> {:error, "branch is behind remote"}
        String.contains?(status, "Your branch is ahead") -> {:error, "unpushed commits"}
        String.contains?(status, "have diverged") -> {:error, "branch has diverged from remote"}
        true -> :ok
      end
    else
      {error, _} -> {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_tests do
    case System.cmd("mix", ["test"], stderr_to_stdout: true, env: [{"MIX_ENV", "test"}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, "tests failed\n#{last_lines(output, 5)}"}
    end
  end

  defp check_format do
    case System.cmd("mix", ["format", "--check-formatted"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, _} -> {:error, "code is not formatted, run: mix format"}
    end
  end

  defp check_credo do
    if has_dep?(:credo) do
      case System.cmd("mix", ["credo", "--strict"], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "credo issues found\n#{last_lines(output, 5)}"}
      end
    else
      :skip
    end
  end

  defp check_dialyzer do
    if has_dep?(:dialyxir) do
      case System.cmd("mix", ["dialyzer"], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "dialyzer errors\n#{last_lines(output, 5)}"}
      end
    else
      :skip
    end
  end

  defp check_changelog(path) do
    case File.read(path) do
      {:ok, content} ->
        if has_unreleased?(content),
          do: :ok,
          else: {:error, "no UNRELEASED section found"}

      {:error, :enoent} ->
        {:error, "#{path} not found"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp check_hex_build do
    case System.cmd("mix", ["hex.build"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, ["error", "Error"]),
          do: {:error, "hex.build issues\n#{last_lines(output, 5)}"},
          else: :ok

      {output, _} ->
        {:error, "hex.build failed\n#{last_lines(output, 5)}"}
    end
  end

  # Changelog operations

  defp has_unreleased?(content), do: content |> String.downcase() |> String.contains?("unreleased")

  defp add_changelog_entry(path, entry) do
    try do
      content = read_or_create_changelog(path)

      updated =
        if has_unreleased?(content) do
          Regex.replace(~r/(##\s*unreleased\s*\n)/i, content, "\\1\n- #{entry}\n")
        else
          Regex.replace(~r/(#[^\n]*\n+)/, content, "\\1## UNRELEASED\n\n- #{entry}\n\n", global: false)
        end

      File.write!(path, updated)
      :ok
    rescue
      e in File.Error -> {:error, Exception.message(e)}
    end
  end

  defp read_or_create_changelog(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, :enoent} -> "# Changelog\n\n"
    end
  end

  defp update_changelog(path, version) do
    content = File.read!(path)
    date = Date.utc_today() |> Date.to_string()
    updated = Regex.replace(~r/##\s*unreleased/i, content, "## #{version} - #{date}")

    if updated == content do
      {:error, "failed to update UNRELEASED section"}
    else
      File.write!(path, updated)
      :ok
    end
  end

  # Release steps

  defp commit_release(changelog_file, version) do
    ["mix.exs", "README.md", changelog_file]
    |> Enum.filter(&File.exists?/1)
    |> Enum.each(&System.cmd("git", ["add", &1], stderr_to_stdout: true))

    case System.cmd("git", ["commit", "-m", "Release v#{version}"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp create_tag(version) do
    tag = "v#{version}"

    case System.cmd("git", ["tag", "-a", tag, "-m", "Release #{tag}"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp push_to_remote(version) do
    with {_, 0} <- System.cmd("git", ["push"], stderr_to_stdout: true),
         {_, 0} <- System.cmd("git", ["push", "origin", "v#{version}"], stderr_to_stdout: true) do
      :ok
    else
      {error, _} -> {:error, String.trim(error)}
    end
  end

  defp create_github_release(version) do
    tag = "v#{version}"

    cond do
      is_nil(System.find_executable("gh")) ->
        info("    (gh CLI not installed)")
        :skip

      !github_repo?() ->
        info("    (not a GitHub repository)")
        :skip

      true ->
        case System.cmd("gh", ["release", "create", tag, "--title", "Release #{tag}", "--generate-notes"],
               stderr_to_stdout: true
             ) do
          {_, 0} -> :ok
          {error, _} -> {:error, "gh release failed: #{String.trim(error)}"}
        end
    end
  end

  defp github_repo? do
    match?({_, 0}, System.cmd("gh", ["repo", "view", "--json", "name"], stderr_to_stdout: true))
  end

  defp publish_to_hex do
    case Mix.shell().cmd("mix hex.publish --yes") do
      0 -> :ok
      _ -> {:error, "hex.publish failed"}
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
    string |> String.split("\n") |> Enum.take(-n) |> Enum.join("\n")
  end

  defp info(msg), do: Mix.shell().info(msg)
  defp error(msg), do: Mix.shell().error(msg)
end
