# Changelog

## UNRELEASED

- Refactor into step-based architecture with two pipelines (check + release) (#5)
- Add `EasyPublish.Step` behaviour for custom steps with `execute/1` callback (#5)
- Add `EasyPublish.Runner` for sequential step execution with option validation (#5)
- Support custom step configuration: `check_steps`, `release_steps`, `prepend_*`, `append_*`, `skip_steps` (#5)

## 0.1.2 - 2026-01-07

- Fix stdin not being passed to hex.publish password prompt

## 0.1.1 - 2026-01-06

- bugfix: check for a clean git workspace

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
