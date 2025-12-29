# Changelog

## UNRELEASED

## 0.1.0

- Initial release
- Complete release workflow: checks, changelog update, commit, tag, push, publish
- Mix task `mix easy_publish.release` with pre-release checks:
  - Git working directory clean
  - On correct branch
  - Git up to date with remote
  - Tests pass
  - Code is formatted
  - Credo analysis (if available)
  - Dialyzer (if available)
  - UNRELEASED section in changelog
  - Hex publish dry-run
- Automatic changelog update: replaces UNRELEASED with version and date
- Configuration via `config.exs`
- CLI flags to skip individual checks
- `--publish` flag to perform full release
- `--dry-run` flag to preview changes
