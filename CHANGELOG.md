# Changelog

## 0.1.0

- Initial release
- Mix task `mix easy_publish.release` with pre-release checks:
  - Git working directory clean
  - On correct branch
  - Git up to date with remote
  - Tests pass
  - Code is formatted
  - Credo analysis (if available)
  - Dialyzer (if available)
  - Changelog entry check
  - Hex publish dry-run
- Configuration via `config.exs`
- CLI flags to skip individual checks
- `--publish` flag to publish after checks pass
