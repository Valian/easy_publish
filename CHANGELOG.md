# Changelog

## 0.1.0 - 2025-12-29

- Add `mix easy_publish.release` task with full release automation
- Support version bumping: `major`, `minor`, `patch`, `current`, or explicit version
- Run pre-release checks: tests, format, credo, dialyzer, changelog, hex.build
- Stream output from long-running checks in real-time
- Support user input during checks (e.g., hex password prompts)
- Add `--changelog-entry` flag for quick releases with inline changelog entries
- Add `--dry-run` mode to validate without making changes
- Create git commits, tags, and GitHub releases automatically
- Configurable via `config/config.exs` or CLI flags
