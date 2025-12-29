defmodule EasyPublish.Version do
  @moduledoc """
  Version parsing and calculation utilities.
  """

  @doc """
  Calculate a new version from current version and bump type.

  ## Examples

      iex> EasyPublish.Version.bump("1.2.3", :major)
      {:ok, "2.0.0"}

      iex> EasyPublish.Version.bump("1.2.3", :minor)
      {:ok, "1.3.0"}

      iex> EasyPublish.Version.bump("1.2.3", :patch)
      {:ok, "1.2.4"}

      iex> EasyPublish.Version.bump("invalid", :patch)
      {:error, "cannot parse current version 'invalid' as semver"}

  """
  def bump(current, bump_type) do
    case Version.parse(current) do
      {:ok, %Version{major: major, minor: minor, patch: patch}} ->
        new_version =
          case bump_type do
            :major -> "#{major + 1}.0.0"
            :minor -> "#{major}.#{minor + 1}.0"
            :patch -> "#{major}.#{minor}.#{patch + 1}"
          end

        {:ok, new_version}

      :error ->
        {:error, "cannot parse current version '#{current}' as semver"}
    end
  end

  @doc """
  Validate an explicit version string and ensure it's greater than current.

  ## Examples

      iex> EasyPublish.Version.validate_explicit("2.0.0", "1.0.0")
      {:ok, "2.0.0"}

      iex> EasyPublish.Version.validate_explicit("1.0.0", "1.0.0")
      {:error, "new version 1.0.0 is the same as current version"}

      iex> EasyPublish.Version.validate_explicit("0.5.0", "1.0.0")
      {:error, "new version 0.5.0 must be greater than current version 1.0.0"}

      iex> EasyPublish.Version.validate_explicit("not.a.version", "1.0.0")
      {:error, "invalid version format 'not.a.version', expected semver (e.g., 1.2.3)"}

  """
  def validate_explicit(version, current_version) do
    with {:ok, new} <- Version.parse(version),
         {:ok, current} <- Version.parse(current_version) do
      case Version.compare(new, current) do
        :gt ->
          {:ok, version}

        :eq ->
          {:error, "new version #{version} is the same as current version"}

        :lt ->
          {:error,
           "new version #{version} must be greater than current version #{current_version}"}
      end
    else
      :error ->
        {:error, "invalid version format '#{version}', expected semver (e.g., 1.2.3)"}
    end
  end

  @doc """
  Parse a version argument (major/minor/patch/current/explicit) against current version.

  ## Examples

      iex> EasyPublish.Version.parse_arg("major", "1.2.3")
      {:ok, "2.0.0"}

      iex> EasyPublish.Version.parse_arg("minor", "1.2.3")
      {:ok, "1.3.0"}

      iex> EasyPublish.Version.parse_arg("patch", "1.2.3")
      {:ok, "1.2.4"}

      iex> EasyPublish.Version.parse_arg("current", "1.2.3")
      {:ok, "1.2.3"}

      iex> EasyPublish.Version.parse_arg("2.0.0", "1.2.3")
      {:ok, "2.0.0"}

  """
  def parse_arg(version_arg, current_version) do
    case version_arg do
      "major" -> bump(current_version, :major)
      "minor" -> bump(current_version, :minor)
      "patch" -> bump(current_version, :patch)
      "current" -> {:ok, current_version}
      explicit -> validate_explicit(explicit, current_version)
    end
  end

  @doc """
  Extract major.minor from a version string for ~> dependency format.

  ## Examples

      iex> EasyPublish.Version.extract_major_minor("1.2.3")
      {1, 2}

      iex> EasyPublish.Version.extract_major_minor("invalid")
      {0, 0}

  """
  def extract_major_minor(version) do
    case Version.parse(version) do
      {:ok, %Version{major: major, minor: minor}} -> {major, minor}
      :error -> {0, 0}
    end
  end
end
