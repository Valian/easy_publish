defmodule EasyPublish.VersionTest do
  use ExUnit.Case, async: true
  doctest EasyPublish.Version

  alias EasyPublish.Version

  describe "bump/2" do
    test "bumps major version" do
      assert Version.bump("1.2.3", :major) == {:ok, "2.0.0"}
      assert Version.bump("0.0.1", :major) == {:ok, "1.0.0"}
      assert Version.bump("9.9.9", :major) == {:ok, "10.0.0"}
    end

    test "bumps minor version" do
      assert Version.bump("1.2.3", :minor) == {:ok, "1.3.0"}
      assert Version.bump("0.0.1", :minor) == {:ok, "0.1.0"}
      assert Version.bump("1.9.9", :minor) == {:ok, "1.10.0"}
    end

    test "bumps patch version" do
      assert Version.bump("1.2.3", :patch) == {:ok, "1.2.4"}
      assert Version.bump("0.0.0", :patch) == {:ok, "0.0.1"}
      assert Version.bump("1.2.99", :patch) == {:ok, "1.2.100"}
    end

    test "returns error for invalid version" do
      assert Version.bump("not-a-version", :patch) ==
               {:error, "cannot parse current version 'not-a-version' as semver"}

      assert Version.bump("1.2", :patch) ==
               {:error, "cannot parse current version '1.2' as semver"}
    end
  end

  describe "validate_explicit/2" do
    test "accepts version greater than current" do
      assert Version.validate_explicit("2.0.0", "1.0.0") == {:ok, "2.0.0"}
      assert Version.validate_explicit("1.0.1", "1.0.0") == {:ok, "1.0.1"}
      assert Version.validate_explicit("1.1.0", "1.0.0") == {:ok, "1.1.0"}
    end

    test "rejects version equal to current" do
      assert Version.validate_explicit("1.0.0", "1.0.0") ==
               {:error, "new version 1.0.0 is the same as current version"}
    end

    test "rejects version less than current" do
      assert Version.validate_explicit("0.9.0", "1.0.0") ==
               {:error, "new version 0.9.0 must be greater than current version 1.0.0"}
    end

    test "returns error for invalid new version" do
      assert Version.validate_explicit("bad", "1.0.0") ==
               {:error, "invalid version format 'bad', expected semver (e.g., 1.2.3)"}
    end

    test "returns error for invalid current version" do
      assert Version.validate_explicit("2.0.0", "bad") ==
               {:error, "invalid version format '2.0.0', expected semver (e.g., 1.2.3)"}
    end
  end

  describe "parse_arg/2" do
    test "handles major/minor/patch keywords" do
      assert Version.parse_arg("major", "1.2.3") == {:ok, "2.0.0"}
      assert Version.parse_arg("minor", "1.2.3") == {:ok, "1.3.0"}
      assert Version.parse_arg("patch", "1.2.3") == {:ok, "1.2.4"}
    end

    test "handles current keyword" do
      assert Version.parse_arg("current", "1.2.3") == {:ok, "1.2.3"}
      assert Version.parse_arg("current", "0.0.1") == {:ok, "0.0.1"}
    end

    test "handles explicit version" do
      assert Version.parse_arg("2.0.0", "1.2.3") == {:ok, "2.0.0"}
    end

    test "rejects invalid explicit version" do
      assert {:error, _} = Version.parse_arg("invalid", "1.2.3")
    end
  end

  describe "extract_major_minor/1" do
    test "extracts major.minor from valid version" do
      assert Version.extract_major_minor("1.2.3") == {1, 2}
      assert Version.extract_major_minor("0.5.0") == {0, 5}
      assert Version.extract_major_minor("10.20.30") == {10, 20}
    end

    test "returns {0, 0} for invalid version" do
      assert Version.extract_major_minor("invalid") == {0, 0}
      assert Version.extract_major_minor("1.2") == {0, 0}
    end
  end
end
