require_relative "../../lib/dependency_manager"

RSpec.describe DependencyManager do
  describe "#update_type" do
    it "returns :unchanged if the two versions are identical" do
      expect(DependencyManager.update_type("0.0.0", "0.0.0")).to eq(:unchanged)
    end

    it "returns :patch if update type is a patch" do
      expect(DependencyManager.update_type("0.0.0", "0.0.1")).to eq(:patch)
    end

    it "returns :minor if update type is a minor" do
      expect(DependencyManager.update_type("0.0.0", "0.1.0")).to eq(:minor)
    end

    it "returns :major if update type is a major" do
      expect(DependencyManager.update_type("0.0.0", "1.0.0")).to eq(:major)
    end

    it "returns the biggest update type" do
      expect(DependencyManager.update_type("0.0.0", "1.2.3")).to eq(:major)
    end

    it "raises an exception if semver not provided" do
      expect { DependencyManager.update_type("1", "0.0.0") }.to raise_exception(DependencyManager::SemverException)
    end
  end

  describe ".allowed_dependency_updates" do
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

  describe ".proposed_dependency_updates" do
    it "returns array of dependencies and semvers that are 'proposed' to be merged" do
      manager = DependencyManager.new
      manager.remove_dependency(name: "foo", version: "1.0.0")
      manager.remove_dependency(name: "bar", version: "0.3.0")
      manager.add_dependency(name: "foo", version: "1.1.0")
      manager.add_dependency(name: "bar", version: "0.3.1")

      expect(manager.proposed_dependency_updates).to eq([
        {
          name: "foo",
          previous_version: "1.0.0",
          next_version: "1.1.0",
        },
        {
          name: "bar",
          previous_version: "0.3.0",
          next_version: "0.3.1",
        },
      ])
    end

    it "returns proposed dependency update with previous_version set to nil, if dependency added and not removed" do
      manager = DependencyManager.new
      manager.add_dependency(name: "foo", version: "1.1.0")

      expect(manager.proposed_dependency_updates).to eq([
        {
          name: "foo",
          previous_version: nil,
          next_version: "1.1.0",
        },
      ])
    end

    it "returns proposed dependency update with next_version set to nil, if dependency removed and not added" do
      manager = DependencyManager.new
      manager.remove_dependency(name: "foo", version: "1.0.0")

      expect(manager.proposed_dependency_updates).to eq([
        {
          name: "foo",
          previous_version: "1.0.0",
          next_version: nil,
        },
      ])
    end
  end

  describe ".add_dependency and .remove_dependency exception-handling" do
    it "raises an exception if dependency is added without a name" do
      manager = DependencyManager.new
      expect { manager.add_dependency(name: nil, version: "1.0.0") }.to raise_exception(DependencyManager::InvalidInput)
    end

    it "raises an exception if dependency is added without a version" do
      manager = DependencyManager.new
      expect { manager.add_dependency(name: "foo", version: nil) }.to raise_exception(DependencyManager::InvalidInput)
    end

    it "raises an exception if dependency is added with a non-semver version" do
      manager = DependencyManager.new
      expect { manager.add_dependency(name: "foo", version: "jellyfish") }.to raise_exception(DependencyManager::SemverException)
    end

    it "raises an exception if the same dependency is added twice" do
      manager = DependencyManager.new
      manager.add_dependency(name: "foo", version: "1.0.0")
      expect { manager.add_dependency(name: "foo", version: "1.1.0") }.to raise_exception(DependencyManager::DependencyConflict)
    end

    it "raises an exception if the same dependency is removed twice" do
      manager = DependencyManager.new
      manager.remove_dependency(name: "foo", version: "1.0.0")
      expect { manager.remove_dependency(name: "foo", version: "1.1.0") }.to raise_exception(DependencyManager::DependencyConflict)
    end
  end

  describe ".all_proposed_dependencies_on_allowlist?" do
    it "returns false if proposed update hasn't been 'allowed' yet" do
      manager = DependencyManager.new
      manager.add_dependency(name: "foo", version: "1.0.0")

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns false if proposed updates contain a dependency that hasn't been 'allowed' yet, amongst ones that have" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.add_dependency(name: "foo", version: "1.0.0")
      manager.add_dependency(name: "something_not_allowed", version: "1.0.0")

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns true if all proposed updates are on the allowlist, even if the semver bumps aren't allowed" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.allow_dependency_update(name: "bar", allowed_semver_bumps: %w[patch])
      manager.remove_dependency(name: "foo", version: "1.0.0")
      manager.remove_dependency(name: "bar", version: "1.0.0")
      manager.add_dependency(name: "foo", version: "1.0.1") # allowed
      manager.add_dependency(name: "bar", version: "2.0.0") # not allowed

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(true)
    end
  end

  describe ".all_proposed_updates_semver_allowed?" do
    # We don't care about whether or not a given dependency is on the allowlist at this point
    # - that's covered by the `all_proposed_dependencies_on_allowlist?` check.
    #  This check should only care about whether a given dependency violates the 'allowed_semver_bumps'
    # that have been explicitly set in the config. If no such config exists for said
    # dependency, let's not block it here.
    it "returns true if a proposed update is missing from the allowlist altogether" do
      manager = DependencyManager.new
      manager.add_dependency(name: "foo", version: "1.0.0")

      expect(manager.all_proposed_updates_semver_allowed?).to eq(true)
    end

    it "returns true if a proposed update type matches that on the allowlist" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.remove_dependency(name: "foo", version: "1.0.0")
      manager.add_dependency(name: "foo", version: "1.0.1")

      expect(manager.all_proposed_updates_semver_allowed?).to eq(true)
    end

    it "returns false if a proposed update type does not match that on the allowlist" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.remove_dependency(name: "foo", version: "1.0.0")
      manager.add_dependency(name: "foo", version: "1.1.0")

      expect(manager.all_proposed_updates_semver_allowed?).to eq(false)
    end

    it "returns false if a proposed update type does not match that on the allowlist, even if others do" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch minor major])
      manager.allow_dependency_update(name: "bar", allowed_semver_bumps: %w[patch])
      manager.remove_dependency(name: "foo", version: "1.0.0")
      manager.remove_dependency(name: "bar", version: "1.0.0")
      manager.add_dependency(name: "foo", version: "1.1.0") # allowed
      manager.add_dependency(name: "bar", version: "2.0.0") # not allowed

      expect(manager.all_proposed_updates_semver_allowed?).to eq(false)
    end
  end
end
