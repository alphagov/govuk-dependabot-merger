require_relative "../../lib/dependency_manager"

RSpec.describe DependencyManager do
  describe "#allowed_dependency_updates" do
    it "returns array of dependencies and semvers that are 'allowed' to be auto-merged" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch minor])
      manager.allow_dependency_update(name: "bar", allowed_semver_bumps: %w[patch])

      expect(manager.allowed_dependency_updates).to eq([
        {
          name: "foo",
          allowed_semver_bumps: %w[patch minor],
        },
        {
          name: "bar",
          allowed_semver_bumps: %w[patch],
        },
      ])
    end
  end

  describe "#determine_allowed_dependencies" do
    it "correctly interprets remote config" do
      remote_config = {
        "api_version" => 1,
        "auto_merge" => [
          {
            "dependency" => "govuk_publishing_components",
            "allowed_semver_bumps" => %w[patch minor],
          },
          {
            "dependency" => "rubocop-govuk",
            "allowed_semver_bumps" => %w[patch],
          },
        ],
      }

      manager = DependencyManager.new
      manager.determine_allowed_dependencies(remote_config)
      expect(manager.allowed_dependency_updates).to eq([
        {
          name: "govuk_publishing_components",
          allowed_semver_bumps: %w[patch minor],
        },
        {
          name: "rubocop-govuk",
          allowed_semver_bumps: %w[patch],
        },
      ])
    end
  end

  describe "#remote_config_exists?" do
    it "returns false if config doesn't exist" do
      remote_config = { "error" => "404" }

      manager = DependencyManager.new
      manager.determine_allowed_dependencies(remote_config)
      expect(manager.remote_config_exists?).to eq(false)
    end

    it "returns true if config exists" do
      remote_config = { "foo" => "bar" }

      manager = DependencyManager.new
      manager.determine_allowed_dependencies(remote_config)
      expect(manager.remote_config_exists?).to eq(true)
    end
  end

  describe "#valid_remote_config?" do
    it "returns false if config has a syntax error" do
      remote_config = { "error" => "syntax" }

      manager = DependencyManager.new
      manager.determine_allowed_dependencies(remote_config)
      expect(manager.valid_remote_config?).to eq(false)
    end

    it "returns false if config is on a different major version" do
      remote_config = { "api_version" => -1 }

      manager = DependencyManager.new
      manager.determine_allowed_dependencies(remote_config)
      expect(manager.valid_remote_config?).to eq(false)
    end

    it "returns true if config looks valid" do
      remote_config = { "api_version" => 1 }

      manager = DependencyManager.new
      manager.determine_allowed_dependencies(remote_config)
      expect(manager.valid_remote_config?).to eq(true)
    end
  end

  describe "#all_proposed_dependencies_on_allowlist?" do
    it "returns false if proposed update hasn't been 'allowed' yet" do
      manager = DependencyManager.new
      manager.change_set.changes << Change.new(Dependency.new("foo"), :patch)

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns false if proposed updates contain a dependency that hasn't been 'allowed' yet, amongst ones that have" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.change_set.changes += [
        Change.new(Dependency.new("foo"), :patch),
        Change.new(Dependency.new("something_not_allowed"), :patch),
      ]

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns true if all proposed updates are on the allowlist, even if the semver bumps aren't allowed" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.allow_dependency_update(name: "bar", allowed_semver_bumps: %w[patch])
      manager.change_set.changes += [
        Change.new(Dependency.new("foo"), :patch), # allowed
        Change.new(Dependency.new("bar"), :major), # not allowed
      ]

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(true)
    end
  end

  describe "#all_proposed_updates_semver_allowed?" do
    # We don't care about whether or not a given dependency is on the allowlist at this point
    # - that's covered by the `all_proposed_dependencies_on_allowlist?` check.
    #  This check should only care about whether a given dependency violates the 'allowed_semver_bumps'
    # that have been explicitly set in the config. If no such config exists for said
    # dependency, let's not block it here.
    it "returns true if a proposed update is missing from the allowlist altogether" do
      manager = DependencyManager.new
      manager.change_set.changes << Change.new(Dependency.new("foo"), :major)

      expect(manager.all_proposed_updates_semver_allowed?).to eq(true)
    end

    it "returns true if a proposed update type matches that on the allowlist" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.change_set.changes << Change.new(Dependency.new("foo"), :patch)

      expect(manager.all_proposed_updates_semver_allowed?).to eq(true)
    end

    it "returns false if a proposed update type does not match that on the allowlist" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.change_set.changes << Change.new(Dependency.new("foo"), :minor)

      expect(manager.all_proposed_updates_semver_allowed?).to eq(false)
    end

    it "returns false if a proposed update type does not match that on the allowlist, even if others do" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch minor major])
      manager.allow_dependency_update(name: "bar", allowed_semver_bumps: %w[patch])
      manager.change_set.changes += [
        Change.new(Dependency.new("foo"), :minor), # allowed
        Change.new(Dependency.new("bar"), :major), # not allowed
      ]

      expect(manager.all_proposed_updates_semver_allowed?).to eq(false)
    end
  end

  describe "#all_proposed_dependencies_are_internal?" do
    it "delegates to Dependency#internal?" do
      dependency = Dependency.new("foo")
      expect(dependency).to receive(:internal?).and_return(true)

      manager = DependencyManager.new
      manager.change_set.changes << Change.new(dependency, :major)
      expect(manager.all_proposed_dependencies_are_internal?).to eq(true)
    end
  end
end
