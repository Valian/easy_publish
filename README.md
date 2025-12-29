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

## Configuration

Configure defaults in your `config/config.exs`:

```elixir
config :easy_publish,
  branch: "main",
  changelog_file: "CHANGELOG.md",
  skip_github_release: false
```

CLI flags always override configuration.

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
