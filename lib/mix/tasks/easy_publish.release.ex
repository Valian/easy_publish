defmodule Mix.Tasks.EasyPublish.Release do
  @shortdoc "Run pre-release checks and optionally publish to Hex"
  @moduledoc """
  Runs a series of checks to ensure your package is ready for release to Hex.

  ## Usage

      mix easy_publish.release [options]

  ## Options

    * `--publish` - Actually publish to Hex after all checks pass (default: false)
    * `--skip-tests` - Skip running tests
    * `--skip-format` - Skip format check
    * `--skip-credo` - Skip credo analysis (only if credo is a dependency)
    * `--skip-dialyzer` - Skip dialyzer (only if dialyzer is a dependency)
    * `--skip-changelog` - Skip changelog check
    * `--skip-git` - Skip all git checks
    * `--skip-hex-dry-run` - Skip hex.publish --dry-run check
    * `--branch NAME` - Required branch name (default: "main")

  ## Configuration

  You can configure defaults in your `config/config.exs`:

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

  CLI flags always override configuration.
  """

  use Mix.Task

  @requirements ["app.config"]

  @switches [
    publish: :boolean,
    skip_tests: :boolean,
    skip_format: :boolean,
    skip_credo: :boolean,
    skip_dialyzer: :boolean,
    skip_changelog: :boolean,
    skip_git: :boolean,
    skip_hex_dry_run: :boolean,
    branch: :string
  ]

  @default_config %{
    branch: "main",
    skip_tests: false,
    skip_format: false,
    skip_credo: false,
    skip_dialyzer: false,
    skip_changelog: false,
    skip_git: false,
    skip_hex_dry_run: false,
    changelog_file: "CHANGELOG.md"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: @switches)
    config = build_config(opts)

    Mix.shell().info([:cyan, "EasyPublish Release Checks", :reset])
    Mix.shell().info([:cyan, String.duplicate("=", 26), :reset])
    Mix.shell().info("")

    checks = [
      {:git_clean, "Git working directory is clean", &check_git_clean/1, config.skip_git},
      {:git_branch, "On #{config.branch} branch", &check_git_branch/1, config.skip_git},
      {:git_up_to_date, "Git is up to date with remote", &check_git_up_to_date/1,
       config.skip_git},
      {:tests, "Tests pass", &check_tests/1, config.skip_tests},
      {:format, "Code is formatted", &check_format/1, config.skip_format},
      {:credo, "Credo analysis passes", &check_credo/1, config.skip_credo},
      {:dialyzer, "Dialyzer passes", &check_dialyzer/1, config.skip_dialyzer},
      {:changelog, "Changelog has entry for current version", &check_changelog/1,
       config.skip_changelog},
      {:hex_dry_run, "Hex publish dry-run succeeds", &check_hex_dry_run/1,
       config.skip_hex_dry_run}
    ]

    results =
      Enum.map(checks, fn {name, description, check_fn, skip} ->
        run_check(name, description, check_fn, config, skip)
      end)

    failed = Enum.filter(results, fn {_, status, _} -> status == :failed end)
    skipped = Enum.filter(results, fn {_, status, _} -> status == :skipped end)
    passed = Enum.filter(results, fn {_, status, _} -> status == :passed end)

    Mix.shell().info("")
    Mix.shell().info([:cyan, "Summary", :reset])
    Mix.shell().info([:cyan, "-------", :reset])
    Mix.shell().info([:green, "Passed: #{length(passed)}", :reset])
    Mix.shell().info([:yellow, "Skipped: #{length(skipped)}", :reset])
    Mix.shell().info([:red, "Failed: #{length(failed)}", :reset])
    Mix.shell().info("")

    cond do
      length(failed) > 0 ->
        Mix.shell().error("Release checks failed. Fix the issues above before publishing.")
        exit({:shutdown, 1})

      opts[:publish] ->
        Mix.shell().info([:green, "All checks passed! Publishing to Hex...", :reset])
        Mix.shell().info("")
        run_hex_publish()

      true ->
        Mix.shell().info([:green, "All checks passed! Ready to publish.", :reset])
        Mix.shell().info("Run with --publish flag to publish to Hex.")
    end
  end

  defp build_config(opts) do
    app_config =
      Enum.reduce(@default_config, %{}, fn {key, default}, acc ->
        value = Application.get_env(:easy_publish, key, default)
        Map.put(acc, key, value)
      end)

    Enum.reduce(opts, app_config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp run_check(name, description, check_fn, config, skip) do
    if skip do
      print_status(description, :skipped)
      {name, :skipped, nil}
    else
      case check_fn.(config) do
        :ok ->
          print_status(description, :passed)
          {name, :passed, nil}

        {:ok, _} ->
          print_status(description, :passed)
          {name, :passed, nil}

        :skip ->
          print_status(description, :skipped, "not available")
          {name, :skipped, nil}

        {:error, reason} ->
          print_status(description, :failed, reason)
          {name, :failed, reason}
      end
    end
  end

  defp print_status(description, status, detail \\ nil) do
    {symbol, color} =
      case status do
        :passed -> {"✓", :green}
        :failed -> {"✗", :red}
        :skipped -> {"○", :yellow}
      end

    detail_str = if detail, do: " (#{detail})", else: ""
    Mix.shell().info([color, "#{symbol} #{description}#{detail_str}", :reset])
  end

  # Git checks

  defp check_git_clean(_config) do
    case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
      {"", 0} -> :ok
      {output, 0} -> {:error, "uncommitted changes:\n#{String.trim(output)}"}
      {error, _} -> {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_git_branch(config) do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} ->
        branch = String.trim(branch)

        if branch == config.branch do
          :ok
        else
          {:error, "on branch '#{branch}', expected '#{config.branch}'"}
        end

      {error, _} ->
        {:error, "git error: #{String.trim(error)}"}
    end
  end

  defp check_git_up_to_date(_config) do
    with {_, 0} <- System.cmd("git", ["fetch"], stderr_to_stdout: true),
         {status, 0} <- System.cmd("git", ["status", "-uno"], stderr_to_stdout: true) do
      cond do
        String.contains?(status, "Your branch is behind") ->
          {:error, "branch is behind remote"}

        String.contains?(status, "Your branch is ahead") ->
          {:error, "branch is ahead of remote (unpushed commits)"}

        String.contains?(status, "have diverged") ->
          {:error, "branch has diverged from remote"}

        true ->
          :ok
      end
    else
      {error, _} -> {:error, "git error: #{String.trim(error)}"}
    end
  end

  # Code quality checks

  defp check_tests(_config) do
    case System.cmd("mix", ["test"], stderr_to_stdout: true, env: [{"MIX_ENV", "test"}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, "tests failed\n#{last_lines(output, 5)}"}
    end
  end

  defp check_format(_config) do
    case System.cmd("mix", ["format", "--check-formatted"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, _} -> {:error, "code is not formatted, run: mix format"}
    end
  end

  defp check_credo(_config) do
    if has_dep?(:credo) do
      case System.cmd("mix", ["credo", "--strict"], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "credo issues found\n#{last_lines(output, 5)}"}
      end
    else
      :skip
    end
  end

  defp check_dialyzer(_config) do
    if has_dep?(:dialyxir) do
      case System.cmd("mix", ["dialyzer"], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "dialyzer errors\n#{last_lines(output, 5)}"}
      end
    else
      :skip
    end
  end

  # Changelog check

  defp check_changelog(config) do
    changelog_file = config.changelog_file
    version = Mix.Project.config()[:version]

    if File.exists?(changelog_file) do
      content = File.read!(changelog_file)

      if String.contains?(content, version) do
        :ok
      else
        {:error, "version #{version} not found in #{changelog_file}"}
      end
    else
      {:error, "#{changelog_file} not found"}
    end
  end

  # Hex checks

  defp check_hex_dry_run(_config) do
    case System.cmd("mix", ["hex.publish", "--dry-run"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "Published") or
             String.contains?(output, "Publishing") or
             String.contains?(output, "Dry run") or
             not String.contains?(output, "error") do
          :ok
        else
          {:error, "hex.publish dry-run issues\n#{last_lines(output, 5)}"}
        end

      {output, _} ->
        {:error, "hex.publish dry-run failed\n#{last_lines(output, 5)}"}
    end
  end

  defp run_hex_publish do
    # Use interactive mode for hex.publish to handle authentication
    port =
      Port.open({:spawn_executable, System.find_executable("mix")}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: ["hex.publish"]
      ])

    stream_port_output(port)
  end

  defp stream_port_output(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        stream_port_output(port)

      {^port, {:exit_status, 0}} ->
        Mix.shell().info([:green, "\nSuccessfully published!", :reset])

      {^port, {:exit_status, _code}} ->
        Mix.shell().error("\nPublish failed!")
        exit({:shutdown, 1})
    end
  end

  # Helpers

  defp has_dep?(dep) do
    Mix.Project.config()[:deps]
    |> Enum.any?(fn
      {^dep, _} -> true
      {^dep, _, _} -> true
      _ -> false
    end)
  end

  defp last_lines(string, n) do
    string
    |> String.split("\n")
    |> Enum.take(-n)
    |> Enum.join("\n")
  end
end
