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
      manager.propose_dependency_update(name: "foo", previous_version: "1.0.0", next_version: "1.1.0")
      manager.propose_dependency_update(name: "bar", previous_version: "0.3.0", next_version: "0.3.1")

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
  end

  describe ".all_proposed_dependencies_on_allowlist?" do
    it "returns false if proposed update hasn't been 'allowed' yet" do
      manager = DependencyManager.new
      manager.propose_dependency_update(name: "foo", previous_version: "1.0.0", next_version: "1.0.1")

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns false if proposed updates contain a dependency that hasn't been 'allowed' yet, amongst ones that have" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.propose_dependency_update(name: "foo", previous_version: "1.0.0", next_version: "1.0.1")
      manager.propose_dependency_update(name: "something_not_allowed", previous_version: "1.0.0", next_version: "1.0.1")

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns true if all proposed updates are on the allowlist, even if the semver bumps aren't allowed" do
      manager = DependencyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.allow_dependency_update(name: "bar", allowed_semver_bumps: %w[patch])
      manager.propose_dependency_update(name: "foo", previous_version: "1.0.0", next_version: "1.0.1") # allowed
      manager.propose_dependency_update(name: "bar", previous_version: "1.0.0", next_version: "2.0.0") # not allowed

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(true)
    end
  end
end