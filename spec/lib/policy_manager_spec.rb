require_relative "../../lib/policy_manager"
require_relative "../../lib/version"

RSpec.describe PolicyManager do
  describe "#defaults" do
    it "returns set of default behaviours" do
      expect(PolicyManager.new.defaults).to eq({
        update_external_dependencies: false,
        auto_merge: true,
        allowed_semver_bumps: %i[patch minor],
      })
    end

    it "can override the default `update_external_dependencies` property via remote config" do
      remote_config = { "defaults" => { "update_external_dependencies" => true } }
      expect(PolicyManager.new(remote_config).defaults[:update_external_dependencies]).to eq(true)
    end

    it "can override the default `auto_merge` property via remote config" do
      remote_config = { "defaults" => { "auto_merge" => false } }
      expect(PolicyManager.new(remote_config).defaults[:auto_merge]).to eq(false)
    end

    it "can override the default `allowed_semver_bumps` property via remote config" do
      remote_config = { "defaults" => { "allowed_semver_bumps" => %i[major] } }
      expect(PolicyManager.new(remote_config).defaults[:allowed_semver_bumps]).to eq(%i[major])
    end
  end

  describe "#dependency_policy" do
    RSpec.shared_examples "doesn't allow auto-merging internal dependencies" do
      let(:expected_policy) { { auto_merge: false, allowed_semver_bumps: [] } }
      it { expect(policy_manager.dependency_policy(internal_dependency)).to eq(expected_policy) }
    end
    RSpec.shared_examples "doesn't allow auto-merging external dependencies" do
      let(:expected_policy) { { auto_merge: false, allowed_semver_bumps: [] } }
      it { expect(policy_manager.dependency_policy(external_dependency)).to eq(expected_policy) }
    end
    RSpec.shared_examples "allows auto-merging internal dependencies" do
      let(:expected_policy) { { auto_merge: true, allowed_semver_bumps: } }
      it { expect(policy_manager.dependency_policy(internal_dependency)).to eq(expected_policy) }
    end
    RSpec.shared_examples "allows auto-merging external dependencies" do
      let(:expected_policy) { { auto_merge: true, allowed_semver_bumps: } }
      it { expect(policy_manager.dependency_policy(external_dependency)).to eq(expected_policy) }
    end
    let(:policy_manager) { PolicyManager.new(remote_config) }
    let(:remote_config) do
      {
        "defaults" => {
          "update_external_dependencies" => update_external_dependencies,
          "auto_merge" => auto_merge,
          "allowed_semver_bumps" => allowed_semver_bumps,
        },
      }
    end
    let(:allowed_semver_bumps) { %i[patch minor] }
    let(:internal_dependency) { stub_internal_dependency("govuk_publishing_components") }
    let(:external_dependency) { stub_external_dependency("foo") }

    context "auto merge disabled, external dependencies disabled" do
      let(:auto_merge) { false }
      let(:update_external_dependencies) { false }

      it_behaves_like "doesn't allow auto-merging internal dependencies"
      it_behaves_like "doesn't allow auto-merging external dependencies"
    end

    context "auto merge disabled, external dependencies enabled" do
      let(:auto_merge) { false }
      let(:update_external_dependencies) { true }

      it_behaves_like "doesn't allow auto-merging internal dependencies"
      it_behaves_like "doesn't allow auto-merging external dependencies"
    end

    context "auto merge enabled, external dependencies disabled" do
      let(:auto_merge) { true }
      let(:update_external_dependencies) { false }

      it_behaves_like "allows auto-merging internal dependencies"
      it_behaves_like "doesn't allow auto-merging external dependencies"
    end

    context "auto merge enabled, external dependencies enabled" do
      let(:auto_merge) { true }
      let(:update_external_dependencies) { true }

      it_behaves_like "allows auto-merging internal dependencies"
      it_behaves_like "allows auto-merging external dependencies"
    end

    context "general tests for overrides" do
      # these `let`s are included so `remote_config` doesn't raise an exception, but each
      # individual test should override the relevant bits of `remote_config["defaults"]`
      # for explicitness.
      let(:auto_merge) { true }
      let(:update_external_dependencies) { true }

      it "refers to overridden 'allowed_semver_bumps' value for dependencies if provided" do
        remote_config["defaults"]["allowed_semver_bumps"] = %i[patch]
        remote_config["overrides"] = [{ "dependency" => internal_dependency, "allowed_semver_bumps" => %i[major] }]
        expect(policy_manager.dependency_policy(internal_dependency)).to eq({
          auto_merge: true,
          allowed_semver_bumps: %i[major],
        })
      end

      it "doesn't allow auto-merging internal dependencies if they override `auto_merge` to false" do
        remote_config["defaults"]["auto_merge"] = true
        remote_config["overrides"] = [{ "dependency" => internal_dependency, "auto_merge" => false }]

        expect(policy_manager.dependency_policy(internal_dependency)).to eq({
          auto_merge: false,
          allowed_semver_bumps: [],
        })
      end

      it "doesn't return overridden 'allowed_semver_bumps' value if dependency isn't eligible for auto-merge" do
        remote_config["defaults"]["allowed_semver_bumps"] = %i[patch]
        remote_config["overrides"] = [{ "dependency" => internal_dependency, "auto_merge" => false, "allowed_semver_bumps" => %i[major] }]
        expect(policy_manager.dependency_policy(internal_dependency)).to eq({
          auto_merge: false,
          allowed_semver_bumps: [],
        })
      end

      it "doesn't allow auto-merging external dependencies if they override `update_external_dependencies` to false" do
        remote_config["defaults"]["auto_merge"] = true
        remote_config["defaults"]["update_external_dependencies"] = true
        remote_config["overrides"] = [{ "dependency" => external_dependency, "update_external_dependencies" => false }]

        expect(policy_manager.dependency_policy(external_dependency)).to eq({
          auto_merge: false,
          allowed_semver_bumps: [],
        })
      end

      it "allows allow-listed external dependencies to be auto-merged" do
        remote_config["defaults"]["auto_merge"] = false
        remote_config["defaults"]["update_external_dependencies"] = true
        remote_config["overrides"] = [{ "dependency" => external_dependency, "auto_merge" => true }]

        expect(policy_manager.dependency_policy(external_dependency)).to eq({
          auto_merge: true,
          allowed_semver_bumps:,
        })
      end

      it "allows overridden internal dependencies to be auto-merged" do
        remote_config["defaults"]["auto_merge"] = false
        remote_config["overrides"] = [{ "dependency" => internal_dependency, "auto_merge" => true }]

        expect(policy_manager.dependency_policy(internal_dependency)).to eq({
          auto_merge: true,
          allowed_semver_bumps:,
        })
      end

      it "doesn't allow overridden external dependencies to be auto-merged (due to `update_external_dependencies`)" do
        remote_config["defaults"]["auto_merge"] = false
        remote_config["defaults"]["update_external_dependencies"] = false
        remote_config["overrides"] = [{ "dependency" => external_dependency, "auto_merge" => true }]

        expect(policy_manager.dependency_policy(external_dependency)).to eq({
          auto_merge: false,
          allowed_semver_bumps: [],
        })
      end

      it "allows overridden external dependencies to be auto-merged if `update_external_dependencies` is overridden to `true`" do
        remote_config["defaults"]["auto_merge"] = false
        remote_config["defaults"]["update_external_dependencies"] = false
        remote_config["overrides"] = [{ "dependency" => external_dependency, "auto_merge" => true, "update_external_dependencies" => true }]

        expect(policy_manager.dependency_policy(external_dependency)).to eq({
          auto_merge: true,
          allowed_semver_bumps:,
        })
      end
    end
  end

  describe "#allowed_dependency_updates" do
    it "returns array of dependencies and semvers that are 'allowed' to be auto-merged" do
      manager = PolicyManager.new
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

    it "works with remote config passed on initialisation" do
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

      manager = PolicyManager.new(remote_config)
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

  describe "#change_allowed?" do
    it "returns false if `auto_merge` is false" do
      policy_manager = PolicyManager.new
      allow(policy_manager).to receive(:dependency_policy).and_return(auto_merge: false)
      expect(policy_manager.change_allowed?("foo", :patch)).to eq(false)
    end

    it "returns false if the requested semver isn't allowed" do
      policy_manager = PolicyManager.new
      allow(policy_manager).to receive(:dependency_policy).and_return(auto_merge: true, allowed_semver_bumps: %i[patch])
      expect(policy_manager.change_allowed?("foo", :minor)).to eq(false)
    end

    it "returns true if both `auto_merge: true` and requested semver is allowed" do
      policy_manager = PolicyManager.new
      allow(policy_manager).to receive(:dependency_policy).and_return(auto_merge: true, allowed_semver_bumps: %i[patch])
      expect(policy_manager.change_allowed?("foo", :patch)).to eq(true)
    end
  end

  describe "#remote_config_exists?" do
    it "returns false if config doesn't exist" do
      remote_config = { "error" => "404" }

      expect(PolicyManager.new(remote_config).remote_config_exists?).to eq(false)
    end

    it "returns true if config exists" do
      remote_config = { "foo" => "bar" }

      expect(PolicyManager.new(remote_config).remote_config_exists?).to eq(true)
    end
  end

  describe "#valid_remote_config_syntax?" do
    it "returns false if config has a syntax error" do
      remote_config = { "error" => "syntax" }

      expect(PolicyManager.new(remote_config).valid_remote_config_syntax?).to eq(false)
    end

    it "returns true if config looks valid" do
      remote_config = { "api_version" => 1 }

      expect(PolicyManager.new(remote_config).valid_remote_config_syntax?).to eq(true)
    end
  end

  describe "#remote_config_api_version_supported?" do
    it "returns false if config is on a different major version" do
      remote_config = { "api_version" => -1 }

      expect(PolicyManager.new(remote_config).remote_config_api_version_supported?).to eq(false)
    end

    it "returns true if config version is supported" do
      remote_config = { "api_version" => DependabotAutoMerge::VERSION }

      expect(PolicyManager.new(remote_config).remote_config_api_version_supported?).to eq(true)
    end
  end

  describe "#is_auto_mergeable? and #reasons_not_to_merge" do
    before do
      stub_internal_dependency("govuk_publishing_components")
    end
    let(:remote_config) do
      {
        "api_version" => DependabotAutoMerge::VERSION,
        "auto_merge" => [
          {
            "dependency" => "govuk_publishing_components",
            "allowed_semver_bumps" => %w[patch minor],
          },
        ],
      }
    end
    let(:mock_pr) do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:commit_message).and_return(
        <<~COMMIT_MESSAGE,
          ---
          updated-dependencies:
          - dependency-name: govuk_publishing_components
            dependency-type: direct:production
            update-type: version-update:semver-minor
        COMMIT_MESSAGE
      )
      mock_pr
    end

    it "should make a call to all_proposed_dependencies_on_allowlist? and return false if false" do
      policy_manager = PolicyManager.new(remote_config)
      expect(policy_manager).to receive(:all_proposed_dependencies_on_allowlist?).and_return(false).at_least(:once)
      expect(policy_manager.is_auto_mergeable?(mock_pr)).to eq(false)
      expect(policy_manager.reasons_not_to_merge(mock_pr)).to eq([
        "PR bumps a dependency that is not on the allowlist.",
      ])
    end

    it "should make a call to all_proposed_updates_semver_allowed? and return false if false" do
      policy_manager = PolicyManager.new(remote_config)
      expect(policy_manager).to receive(:all_proposed_updates_semver_allowed?).and_return(false).at_least(:once)
      expect(policy_manager.is_auto_mergeable?(mock_pr)).to eq(false)
      expect(policy_manager.reasons_not_to_merge(mock_pr)).to eq([
        "PR bumps a dependency to a higher semver than is allowed.",
      ])
    end

    it "should make a call to all_proposed_dependencies_are_internal? and return false if false" do
      policy_manager = PolicyManager.new(remote_config)
      expect(policy_manager).to receive(:all_proposed_dependencies_are_internal?).and_return(false).at_least(:once)
      expect(policy_manager.is_auto_mergeable?(mock_pr)).to eq(false)
      expect(policy_manager.reasons_not_to_merge(mock_pr)).to eq([
        "PR bumps an external dependency.",
      ])
    end
  end

  describe "#all_proposed_dependencies_on_allowlist?" do
    it "returns false if proposed update hasn't been 'allowed' yet" do
      manager = PolicyManager.new
      manager.change_set.changes << Change.new(Dependency.new("foo"), :patch)

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns false if proposed updates contain a dependency that hasn't been 'allowed' yet, amongst ones that have" do
      manager = PolicyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.change_set.changes += [
        Change.new(Dependency.new("foo"), :patch),
        Change.new(Dependency.new("something_not_allowed"), :patch),
      ]

      expect(manager.all_proposed_dependencies_on_allowlist?).to eq(false)
    end

    it "returns true if all proposed updates are on the allowlist, even if the semver bumps aren't allowed" do
      manager = PolicyManager.new
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
      manager = PolicyManager.new
      manager.change_set.changes << Change.new(Dependency.new("foo"), :major)

      expect(manager.all_proposed_updates_semver_allowed?).to eq(true)
    end

    it "returns true if a proposed update type matches that on the allowlist" do
      manager = PolicyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.change_set.changes << Change.new(Dependency.new("foo"), :patch)

      expect(manager.all_proposed_updates_semver_allowed?).to eq(true)
    end

    it "returns false if a proposed update type does not match that on the allowlist" do
      manager = PolicyManager.new
      manager.allow_dependency_update(name: "foo", allowed_semver_bumps: %w[patch])
      manager.change_set.changes << Change.new(Dependency.new("foo"), :minor)

      expect(manager.all_proposed_updates_semver_allowed?).to eq(false)
    end

    it "returns false if a proposed update type does not match that on the allowlist, even if others do" do
      manager = PolicyManager.new
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

      manager = PolicyManager.new
      manager.change_set.changes << Change.new(dependency, :major)
      expect(manager.all_proposed_dependencies_are_internal?).to eq(true)
    end
  end

  def stub_internal_dependency(dependency_name)
    stub_request(:get, "https://rubygems.org/api/v1/gems/#{dependency_name}/owners.yaml").to_return(
      status: 200,
      body: "- handle: govuk",
    )
    dependency_name
  end

  def stub_external_dependency(dependency_name)
    stub_request(:get, "https://rubygems.org/api/v1/gems/#{dependency_name}/owners.yaml").to_return(
      status: 200,
      body: "- handle: someone_else",
    )
    dependency_name
  end
end
