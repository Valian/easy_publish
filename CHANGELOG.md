# Changelog

## 0.2.2 - 2026-02-20

- Fix tests running with wrong `MIX_ENV` when the host project uses env-dependent config (e.g. `consolidate_protocols: Mix.env() != :test`). Tests now run as a subprocess with `MIX_ENV=test`.
- Fix release proceeding even when tests fail. `ExUnit` defers its exit to `System.at_exit`, so the in-process runner never saw the failure.
- `--dry-run` now runs all checks for real instead of faking them. Only release steps are skipped.

## 0.2.1 - 2026-02-19

- Fix `hex.publish` publishing the old version after a version bump. The Mix project module had the previous `@version` cached in memory; it is now reloaded from disk after updating `mix.exs`.

## 0.2.0 - 2026-02-19

### Breaking changes

- The monolithic release task has been split into individual step modules. If you were relying on internal functions of `Mix.Tasks.EasyPublish.Release`, they have moved. The `mix easy_publish.release` CLI interface is unchanged. (#5)

### New features

- **Customizable release pipeline** — each check and release action is now a separate step module. You can replace, prepend, append, or skip steps via config. For example, skip dialyzer with `skip_steps: [EasyPublish.Steps.Dialyzer]` or add a Slack notification with `append_release_steps: [MyApp.NotifySlack]`. (#5)
- **Custom step behaviour** — implement `EasyPublish.Step` to write your own steps with `use EasyPublish.Step, name: "My step"` and an `execute/1` callback. Steps can declare their own options and return `:ok`, `:skip`, or `{:error, reason}`. (#5)
- **Option validation** — misspelled options are now caught before the release starts, with "did you mean?" suggestions. Validation covers options from both the check and release pipelines. (#6)

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
