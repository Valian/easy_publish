# EasyPublish

A complete release tool for Hex packages. Updates version numbers, runs pre-release checks, updates changelog, commits, tags, pushes, creates GitHub release, and publishes to Hex.

## Installation

Add `easy_publish` to your list of dependencies in `mix.exs` as a dev-only dependency:

```elixir
def deps do
  [
    {:easy_publish, "~> 0.2", only: :dev, runtime: false}
  ]
end
```

## Usage

Perform a full release:

```bash
# Bump patch version (0.1.0 -> 0.1.1)
mix easy_publish.release patch

# Bump minor version (0.1.0 -> 0.2.0)
mix easy_publish.release minor

# Bump major version (0.1.0 -> 1.0.0)
mix easy_publish.release major

# Release current version as-is (for initial release)
mix easy_publish.release current

# Set explicit version
mix easy_publish.release 2.0.0
```

Run checks only (no changes made):

```bash
mix easy_publish.release patch --dry-run
```

## Release Flow

EasyPublish uses a step-based architecture with two pipelines:

1. **Check pipeline** - Validates preconditions before any changes are made
2. **Release pipeline** - Performs the actual release (version bump, commit, tag, publish)

Each step implements an `execute/1` callback. If any step fails, the pipeline halts.

### Default Steps

| # | Step | Module | Phase | Description |
|---|------|--------|-------|-------------|
| 1 | Git working directory is clean | `GitClean` | check | Ensures no uncommitted changes exist |
| 2 | On correct branch | `GitBranch` | check | Verifies current branch matches expected (default: `main`) |
| 3 | Git is up to date with remote | `GitUpToDate` | check | Checks local branch isn't behind/ahead/diverged from remote |
| 4 | Tests pass | `Tests` | check | Runs `mix test` |
| 5 | Code is formatted | `Format` | check | Runs `mix format --check-formatted` |
| 6 | Credo analysis passes | `Credo` | check | Runs `mix credo --strict` (skipped if not installed) |
| 7 | Dialyzer passes | `Dialyzer` | check | Runs `mix dialyzer` (skipped if not installed) |
| 8 | Changelog | `Changelog` | check+run | Validates UNRELEASED section exists, then updates it |
| 9 | Hex package builds successfully | `HexBuild` | check | Runs `mix hex.build` to validate package |
| 10 | Updating version files | `UpdateVersion` | run | Updates `@version` in mix.exs and README.md dependency |
| 11 | Committing release | `GitCommit` | run | Commits mix.exs, README.md, and CHANGELOG.md |
| 12 | Creating git tag | `GitTag` | run | Creates annotated tag `vX.Y.Z` |
| 13 | Pushing to remote | `GitPush` | run | Pushes commit and tag to remote |
| 14 | Creating GitHub release | `GitHubRelease` | run | Creates GitHub release via `gh` CLI (skipped if not available) |
| 15 | Publishing to Hex | `HexPublish` | run | Runs `mix hex.publish --yes` |

All step modules are under `EasyPublish.Steps.*`.

### Custom Steps

Create custom steps by implementing the `EasyPublish.Step` behaviour:

```elixir
defmodule MyApp.Steps.NotifySlack do
  use EasyPublish.Step, name: "Notify Slack"
  # `use EasyPublish.Step` imports helper functions: info/1, warn/1, error/1,
  # git/1, run_mix_task/1, has_dep?/1, has_executable?/1

  @impl true
  def options do
    [{:slack_webhook, type: :string, required: true, doc: "Slack webhook URL"}]
  end

  @impl true
  def execute(ctx) do
    if ctx.dry_run do
      info("Would notify Slack")
      :ok
    else
      # Send notification
      :ok
    end
  end
end
```

**Return values:**
- `:ok` - Success
- `{:ok, updated_ctx}` - Success with updated context
- `:skip` - Skipped (no reason shown)
- `{:skip, reason}` - Skipped with reason
- `{:error, reason}` - Failure, halts pipeline

### Configuring Steps

```elixir
# config/config.exs

# Replace all default steps entirely
config :easy_publish,
  check_steps: [
    EasyPublish.Steps.GitClean,
    EasyPublish.Steps.Tests
  ],
  release_steps: [
    EasyPublish.Steps.UpdateVersion,
    MyApp.Steps.CustomStep,
    EasyPublish.Steps.HexPublish
  ]

# Or modify defaults
config :easy_publish,
  prepend_check_steps: [MyApp.Steps.BeforeChecks],
  append_release_steps: [MyApp.Steps.NotifySlack],
  skip_steps: [EasyPublish.Steps.Dialyzer]
```

## Changelog Format

Your `CHANGELOG.md` should have an UNRELEASED section:

```markdown
# Changelog

## UNRELEASED

- Added new feature
- Fixed bug

## 0.1.0 - 2024-01-15

- Initial release
```

When you run `mix easy_publish.release minor` for version 0.2.0, it becomes:

```markdown
# Changelog

## 0.2.0 - 2024-01-20

- Added new feature
- Fixed bug

## 0.1.0 - 2024-01-15

- Initial release
```

## Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Only run checks, don't make any changes |
| `--skip-tests` | Skip running tests |
| `--skip-format` | Skip format check |
| `--skip-credo` | Skip credo analysis |
| `--skip-dialyzer` | Skip dialyzer |
| `--skip-changelog` | Skip changelog check |
| `--skip-git` | Skip all git checks |
| `--skip-hex-build` | Skip hex.build validation |
| `--skip-github-release` | Skip GitHub release creation |
| `--branch NAME` | Required branch name (default: "main") |
| `--changelog-entry CONTENT` | Add a changelog entry and skip UNRELEASED check |

### Quick releases with `--changelog-entry`

For quick releases where you don't want to manually edit the changelog first:

```bash
# Add a changelog entry and release in one command
mix easy_publish.release patch --changelog-entry "Fixed authentication bug"

# Multiple changes can be separated by newlines
mix easy_publish.release minor --changelog-entry "Added user profiles
Fixed memory leak
Updated dependencies"
```

This will:
1. Add the entry to the UNRELEASED section (creating it if needed)
2. Skip the UNRELEASED section check
3. Proceed with the normal release flow

## Configuration

Configure defaults in your `config/config.exs`:

```elixir
config :easy_publish,
  branch: "main",
  changelog_file: "CHANGELOG.md",
  skip_github_release: false,
  skip_tests: false,
  skip_format: false,
  skip_credo: false,
  skip_dialyzer: false,
  skip_changelog: false,
  skip_git: false,
  skip_hex_build: false
```

CLI flags always override configuration.

### Example configurations

**CI-friendly config** (skip slow checks locally, run them in CI):

```elixir
# config/dev.exs
config :easy_publish,
  skip_dialyzer: true,
  skip_credo: true
```

**Non-GitHub project** (skip GitHub release creation):

```elixir
config :easy_publish,
  skip_github_release: true
```

**Custom branch workflow**:

```elixir
config :easy_publish,
  branch: "develop"
```

### CLI examples

```bash
# Full release with all checks
mix easy_publish.release patch

# Quick release skipping slow checks
mix easy_publish.release patch --skip-dialyzer --skip-credo

# Dry run to validate everything first
mix easy_publish.release minor --dry-run

# Release from a feature branch (not recommended for production)
mix easy_publish.release patch --branch feature/my-branch --skip-git

# Initial release of a new package
mix easy_publish.release current

# Quick bugfix release
mix easy_publish.release patch --changelog-entry "Fixed crash on startup"
```

## GitHub Release

GitHub releases are created automatically using the `gh` CLI if:
- `gh` CLI is installed
- The repository is hosted on GitHub
- `--skip-github-release` is not set

If `gh` is not installed or the repo is not on GitHub, this step is silently skipped.

To install `gh`:
- macOS: `brew install gh`
- Linux: See https://github.com/cli/cli#installation

## License

MIT
