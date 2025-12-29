# EasyPublish

A complete release tool for Hex packages. Updates version numbers, runs pre-release checks, updates changelog, commits, tags, pushes, creates GitHub release, and publishes to Hex.

## Installation

Add `easy_publish` to your list of dependencies in `mix.exs` as a dev-only dependency:

```elixir
def deps do
  [
    {:easy_publish, "~> 0.1", only: :dev, runtime: false}
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

### Phase 1: Version Updates

Updates version in all relevant files:
- `mix.exs` - updates `@version` attribute
- `README.md` - updates dependency version (e.g., `{:my_package, "~> 0.2"}`)

### Phase 2: Pre-release Checks

1. Git working directory is clean
2. On correct branch (default: `main`)
3. Git is up to date with remote
4. Tests pass (`mix test`)
5. Code is formatted (`mix format --check-formatted`)
6. Credo passes (if installed)
7. Dialyzer passes (if installed)
8. **UNRELEASED section exists in changelog**
9. `mix hex.build` succeeds (validates package)

### Phase 3: Release

1. Updates changelog: replaces `## UNRELEASED` with `## X.Y.Z - YYYY-MM-DD`
2. Commits all version changes (mix.exs, README.md, CHANGELOG.md)
3. Creates git tag `vX.Y.Z`
4. Pushes commit and tag to remote
5. Creates GitHub release (if `gh` CLI available)
6. Publishes to Hex

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
| `--skip-hex-dry-run` | Skip hex.build validation |
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
  skip_hex_dry_run: false
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
