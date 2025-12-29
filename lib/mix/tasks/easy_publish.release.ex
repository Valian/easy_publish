defmodule Mix.Tasks.EasyPublish.Release do
  @shortdoc "Run pre-release checks and publish to Hex"
  @moduledoc """
  A complete release tool for Hex packages. Runs checks, updates changelog,
  commits, tags, pushes, and publishes to Hex.

  ## Usage

      mix easy_publish.release [options]

  By default, performs the full release. Use `--dry-run` to only run checks.

  ## Release Flow

  1. **Checks** - Validates everything is ready:
     - Git working directory is clean
     - On correct branch (default: main)
     - Git is up to date with remote
     - Tests pass
     - Code is formatted
     - Credo passes (if installed)
     - Dialyzer passes (if installed)
     - UNRELEASED section exists in changelog
     - `hex.publish --dry-run` succeeds

  2. **Release**:
     - Updates changelog: replaces UNRELEASED with version and date
     - Commits the changelog change
     - Creates git tag (vX.Y.Z)
     - Pushes commit and tag to remote
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
    changelog_file: "CHANGELOG.md"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: @switches)
    config = build_config(opts)
    version = Mix.Project.config()[:version]

    Mix.shell().info([:cyan, "EasyPublish Release v#{version}", :reset])
    Mix.shell().info([:cyan, String.duplicate("=", 24 + String.length(version)), :reset])
    Mix.shell().info("")

    if config.dry_run do
      Mix.shell().info([:yellow, "DRY RUN - only running checks", :reset])
      Mix.shell().info("")
    end

    # Phase 1: Checks
    Mix.shell().info([:cyan, "Phase 1: Pre-release Checks", :reset])
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
      {:hex_dry_run, "Hex publish dry-run succeeds", &check_hex_dry_run/1,
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

    # Phase 2: Release (unless --dry-run)
    if config.dry_run do
      Mix.shell().info([:green, "All checks passed!", :reset])
      Mix.shell().info("Run without --dry-run to perform the release.")
    else
      Mix.shell().info([:cyan, "Phase 2: Release", :reset])
      Mix.shell().info("")

      release_steps(config, version)
    end
  end

  defp release_steps(config, version) do
    steps = [
      {"Updating changelog", &update_changelog/2},
      {"Committing changelog", &commit_changelog/2},
      {"Creating git tag v#{version}", &create_tag/2},
      {"Pushing to remote", &push_to_remote/2},
      {"Publishing to Hex", &publish_to_hex/2}
    ]

    Enum.reduce_while(steps, :ok, fn {description, step_fn}, _acc ->
      Mix.shell().info([:cyan, "→ ", :reset, description, "..."])

      case step_fn.(config, version) do
        :ok ->
          Mix.shell().info([:green, "  ✓ Done", :reset])
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
    case System.cmd("mix", ["hex.publish", "--dry-run"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "error") and not String.contains?(output, "No errors") do
          {:error, "hex.publish dry-run issues\n#{last_lines(output, 5)}"}
        else
          :ok
        end

      {output, _} ->
        {:error, "hex.publish dry-run failed\n#{last_lines(output, 5)}"}
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

  defp commit_changelog(config, version) do
    changelog_file = config.changelog_file

    case System.cmd("git", ["add", changelog_file], stderr_to_stdout: true) do
      {_, 0} ->
        case System.cmd("git", ["commit", "-m", "Release v#{version}"], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {error, _} -> {:error, String.trim(error)}
        end

      {error, _} ->
        {:error, String.trim(error)}
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
