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

      it "converts default allowed_semver_bumps to symbols" do
        remote_config["defaults"]["allowed_semver_bumps"] = %w[patch minor]

        expect(policy_manager.dependency_policy(external_dependency)).to eq({
          auto_merge: true,
          allowed_semver_bumps: %i[patch minor],
        })
      end

      it "converts overridden allowed_semver_bumps to symbols" do
        remote_config["overrides"] = [{ "dependency" => external_dependency, "allowed_semver_bumps" => %w[patch] }]

        expect(policy_manager.dependency_policy(external_dependency)).to eq({
          auto_merge: true,
          allowed_semver_bumps: %i[patch],
        })
      end
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
    let(:internal_dependency) { stub_internal_dependency("govuk_publishing_components") }
    let(:external_dependency) { stub_external_dependency("foo") }
    let(:remote_config) do
      {
        "api_version" => DependabotAutoMerge::VERSION,
        "defaults" => {
          "auto_merge" => true,
          "update_external_dependencies" => true,
          "allowed_semver_bumps" => %i[patch minor],
        },
        "overrides" => [
          {
            # example of being stricter about semver for certain dependencies
            "dependency" => internal_dependency,
            "allowed_semver_bumps" => %i[patch],
          },
          {
            # example of deny-listing a named external dependency
            "dependency" => external_dependency,
            "update_external_dependencies" => false,
          },
        ],
      }
    end

    it "should return reasons not to merge the example internal dependency" do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:commit_message).and_return(
        <<~COMMIT_MESSAGE,
          ---
          updated-dependencies:
          - dependency-name: #{internal_dependency}
            dependency-type: direct:production
            update-type: version-update:semver-minor
        COMMIT_MESSAGE
      )

      expect(PolicyManager.new(remote_config).is_auto_mergeable?(mock_pr)).to eq(false)
      expect(PolicyManager.new(remote_config).reasons_not_to_merge(mock_pr)).to eq([
        "govuk_publishing_components minor increase is not allowed by the derived policy for this dependency: {:auto_merge=>true, :allowed_semver_bumps=>[:patch]}",
      ])
    end

    it "should return reasons not to merge the example external dependency" do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:commit_message).and_return(
        <<~COMMIT_MESSAGE,
          ---
          updated-dependencies:
          - dependency-name: #{external_dependency}
            dependency-type: direct:production
            update-type: version-update:semver-minor
        COMMIT_MESSAGE
      )

      expect(PolicyManager.new(remote_config).is_auto_mergeable?(mock_pr)).to eq(false)
      expect(PolicyManager.new(remote_config).reasons_not_to_merge(mock_pr)).to eq([
        "foo minor increase is not allowed by the derived policy for this dependency: {:auto_merge=>false, :allowed_semver_bumps=>[]}",
      ])
    end

    it "should return empty array if nothing wrong" do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:commit_message).and_return(
        <<~COMMIT_MESSAGE,
          ---
          updated-dependencies:
          - dependency-name: #{internal_dependency}
            dependency-type: indirect
            update-type: version-update:semver-patch
        COMMIT_MESSAGE
      )

      expect(PolicyManager.new(remote_config).is_auto_mergeable?(mock_pr)).to eq(true)
      expect(PolicyManager.new(remote_config).reasons_not_to_merge(mock_pr)).to eq([])
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
