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

  By default, performs the full release. Use `--dry-run` to preview what would happen.

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
     - `hex.build` succeeds (validates package)

  2. **Release**:
     - Updates version in mix.exs and README.md
     - Updates changelog: replaces UNRELEASED with version and date
     - Commits all version changes
     - Creates git tag (vX.Y.Z)
     - Pushes commit and tag to remote
     - Creates GitHub release (if gh CLI available)
     - Publishes to Hex

  ## Options

    * `--dry-run` - Preview what would happen without making changes
    * `--skip-tests` - Skip running tests
    * `--skip-format` - Skip format check
    * `--skip-credo` - Skip credo analysis
    * `--skip-dialyzer` - Skip dialyzer
    * `--skip-changelog` - Skip changelog check
    * `--skip-git` - Skip all git checks
    * `--skip-hex-build` - Skip hex.build validation
    * `--skip-github-release` - Skip GitHub release creation
    * `--branch NAME` - Required branch name (default: "main")
    * `--changelog-entry CONTENT` - Add a changelog entry automatically
    * `--changelog-file PATH` - Path to changelog (default: "CHANGELOG.md")

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
        skip_hex_build: false,
        skip_github_release: false,
        changelog_file: "CHANGELOG.md"

  CLI flags always override configuration.

  ## Custom Steps

  You can customize the release pipelines by configuring steps:

      # Replace all steps
      config :easy_publish,
        check_steps: [
          EasyPublish.Steps.GitClean,
          EasyPublish.Steps.Tests
        ],
        release_steps: [
          EasyPublish.Steps.UpdateVersion,
          EasyPublish.Steps.HexPublish
        ]

      # Or modify defaults
      config :easy_publish,
        prepend_check_steps: [MyApp.BeforeChecks],
        append_release_steps: [MyApp.NotifySlack],
        skip_steps: [EasyPublish.Steps.Dialyzer]

  ## CI/Automation

  For automated publishing (e.g., in CI), set the `HEX_API_KEY` environment variable
  instead of using interactive authentication:

      # Generate a key with publish permissions
      mix hex.user key generate --key-name publish-ci --permission api:write

      # Use in CI
      HEX_API_KEY=your_key mix easy_publish.release patch

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
    skip_hex_build: :boolean,
    skip_github_release: :boolean,
    branch: :string,
    changelog_entry: :string,
    changelog_file: :string
  ]

  @impl Mix.Task
  def run(args) do
    Mix.ensure_application!(:hex)
    {opts, rest} = OptionParser.parse!(args, strict: @switches)
    current_version = Mix.Project.config()[:version]

    case parse_version_arg(rest, current_version) do
      {:ok, new_version} ->
        do_release(opts, current_version, new_version)

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

  defp do_release(cli_opts, current_version, new_version) do
    print_header(current_version, new_version)

    check_steps = EasyPublish.Steps.resolve_check_steps()
    release_steps = EasyPublish.Steps.resolve_release_steps()

    # Collect options from both pipelines so typos are caught regardless of which pipeline runs
    check_options = EasyPublish.Runner.collect_options(check_steps)
    release_options = EasyPublish.Runner.collect_options(release_steps)

    # Merge CLI opts with app config, add version info
    opts =
      cli_opts
      |> merge_with_app_config()
      |> Keyword.put(:version_current, current_version)
      |> Keyword.put(:version_new, new_version)
      |> Keyword.put(:dry_run, Keyword.get(cli_opts, :dry_run, false))

    if opts[:dry_run] do
      Mix.shell().info([:yellow, "DRY RUN - previewing what would happen"])
      Mix.shell().info("")
    end

    Mix.shell().info([:cyan, "Running Checks"])
    Mix.shell().info("")

    with {:ok, ctx} <-
           EasyPublish.Runner.run(check_steps, opts, extra_known_options: release_options) do
      Mix.shell().info("")
      Mix.shell().info([:cyan, "Running Release"])
      Mix.shell().info("")

      case EasyPublish.Runner.run(release_steps, Keyword.new(ctx),
             extra_known_options: check_options
           ) do
        {:ok, _ctx} ->
          Mix.shell().info("")

          if opts[:dry_run] do
            Mix.shell().info([:green, "Dry run complete!"])
            Mix.shell().info("Run without --dry-run to perform the release.")
          else
            Mix.shell().info([:green, "Successfully released v#{new_version}!"])
          end

        {:error, reason} ->
          Mix.shell().info("")
          Mix.shell().error("Release failed: #{reason}")
          exit({:shutdown, 1})
      end
    else
      {:error, reason} ->
        Mix.shell().info("")
        Mix.shell().error("Checks failed: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp print_header(current_version, new_version) do
    Mix.shell().info([:cyan, "EasyPublish Release"])
    Mix.shell().info([:cyan, "==================="])
    Mix.shell().info("")
    Mix.shell().info(["Version: ", :yellow, current_version, :reset, " → ", :green, new_version])
    Mix.shell().info("")
  end

  defp merge_with_app_config(cli_opts) do
    # Get all keys from switches that have app config equivalents
    config_keys = [
      :branch,
      :skip_tests,
      :skip_format,
      :skip_credo,
      :skip_dialyzer,
      :skip_changelog,
      :skip_git,
      :skip_hex_build,
      :skip_github_release,
      :changelog_file,
      :changelog_entry
    ]

    # Start with app config defaults
    base =
      Enum.map(config_keys, fn key ->
        {key, Application.get_env(:easy_publish, key)}
      end)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    # CLI opts override app config
    Keyword.merge(base, cli_opts)
  end

  defp parse_version_arg([], _current), do: {:error, "VERSION argument is required"}
  defp parse_version_arg([arg | _], current), do: EasyPublish.Version.parse_arg(arg, current)
end
