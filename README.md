# EasyPublish

A Mix task that runs pre-release checks to ensure your Elixir package is ready for publication to Hex.

## Installation

Add `easy_publish` to your list of dependencies in `mix.exs` as a dev-only dependency:

```elixir
def deps do
  [
    {:easy_publish, "~> 0.1.0", only: :dev, runtime: false}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

Run the release checks:

```bash
mix easy_publish.release
```

If all checks pass and you want to publish:

```bash
mix easy_publish.release --publish
```

## Checks Performed

1. **Git working directory is clean** - No uncommitted changes
2. **On correct branch** - Default: `main`
3. **Git is up to date with remote** - No unpushed commits, not behind remote
4. **Tests pass** - `mix test`
5. **Code is formatted** - `mix format --check-formatted`
6. **Credo analysis passes** - Only if credo is a dependency
7. **Dialyzer passes** - Only if dialyxir is a dependency
8. **Changelog has entry for current version** - Checks CHANGELOG.md
9. **Hex publish dry-run succeeds** - `mix hex.publish --dry-run`

## Options

| Flag | Description |
|------|-------------|
| `--publish` | Actually publish to Hex after all checks pass |
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
  skip_tests: false,
  skip_format: false,
  skip_credo: false,
  skip_dialyzer: false,
  skip_changelog: false,
  skip_git: false,
  skip_hex_dry_run: false,
  changelog_file: "CHANGELOG.md"
```

CLI flags always override configuration.

## License

MIT
