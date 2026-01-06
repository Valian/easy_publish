# EasyPublish

Elixir/Mix release automation tool for Hex packages.

## Project Structure

```
lib/
  easy_publish.ex              # Main module (minimal)
  easy_publish/version.ex      # Version parsing/bumping logic
  mix/tasks/easy_publish.release.ex  # The release task (core logic)
test/
  easy_publish/version_test.exs
  mix/tasks/easy_publish_release_test.exs
```

## Commands

```bash
mix test                    # Run tests
mix format                  # Format code
mix easy_publish.release patch --dry-run  # Test release flow
```

## Architecture

Single Mix task (`mix easy_publish.release`) with three phases:
1. **Version Update** - Updates `@version` in mix.exs and README dependency
2. **Checks** - Git state, tests, format, credo, dialyzer, changelog, hex.build
3. **Release** - Changelog update, commit, tag, push, GitHub release, hex.publish

Version logic lives in `EasyPublish.Version` - semver parsing, bumping, validation.

## Patterns

- Uses `Mix.shell()` for output (colorized via IO lists)
- Checks return `:ok | :skip | {:error, reason}`
- Long-running checks use `run_streaming/3` for real-time output
- Config via Application env, CLI flags override

## Dependencies

Only `ex_doc` (dev-only). No runtime deps.

## Testing Notes

Tests use `Mix.Shell.Process` to capture output. Error cases use `catch_exit/1`.
