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
end
