# EasyPublish

A complete release tool for Hex packages. Runs pre-release checks, updates changelog, commits, tags, pushes, and publishes to Hex.

## Installation

Add `easy_publish` to your list of dependencies in `mix.exs` as a dev-only dependency:

```elixir
def deps do
  [
    {:easy_publish, "~> 0.1.0", only: :dev, runtime: false}
  ]
end
```

## Usage

Perform a full release:

```bash
mix easy_publish.release
```

Run checks only (no changes made):

```bash
mix easy_publish.release --dry-run
```

## Release Flow

### Phase 1: Pre-release Checks

1. Git working directory is clean
2. On correct branch (default: `main`)
3. Git is up to date with remote
4. Tests pass (`mix test`)
5. Code is formatted (`mix format --check-formatted`)
6. Credo passes (if installed)
7. Dialyzer passes (if installed)
8. **UNRELEASED section exists in changelog**
9. `mix hex.publish --dry-run` succeeds

### Phase 2: Release (with `--publish`)

1. Updates changelog: replaces `## UNRELEASED` with `## X.Y.Z - YYYY-MM-DD`
2. Commits the changelog change
3. Creates git tag `vX.Y.Z`
4. Pushes commit and tag to remote
5. Publishes to Hex

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

When you run `mix easy_publish.release --publish` for version 0.2.0, it becomes:

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
| `--skip-hex-dry-run` | Skip hex.publish --dry-run check |
| `--branch NAME` | Required branch name (default: "main") |

## Configuration

Configure defaults in your `config/config.exs`:

```elixir
config :easy_publish,
  branch: "main",
  changelog_file: "CHANGELOG.md"
```

CLI flags always override configuration.

## License

MIT
