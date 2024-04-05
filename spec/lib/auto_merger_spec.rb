require "date"
require_relative "../../lib/auto_merger"

RSpec.describe AutoMerger do
  before :each do
    allow($stdout).to receive(:puts) # suppress console output as it gets noisy
  end

  describe ".invoke_merge_script!" do
    it "should fail silently if this is a bank holiday" do
      allow(Date).to receive(:bank_holidays).and_return([Date.today])

      expect(AutoMerger).not_to receive(:merge_dependabot_prs)
      expect { AutoMerger.invoke_merge_script! }.to output("Today is a bank holiday. Skipping auto-merge.\n").to_stdout
    end
  end

  describe ".merge_dependabot_prs" do
    let!(:policy_manager) do
      mock_policy_manager = instance_double("PolicyManager")
      allow(mock_policy_manager).to receive(:remote_config_exists?).and_return(true)
      allow(mock_policy_manager).to receive(:valid_remote_config_syntax?).and_return(true)
      allow(mock_policy_manager).to receive(:remote_config_api_version_supported?).and_return(true)
      allow(PolicyManager).to receive(:new).and_return(mock_policy_manager)
      mock_policy_manager
    end
    let(:mock_pr) do
      instance_double("PullRequest", number: 1, is_auto_mergeable?: true, approve!: true, merge!: true)
    end

    it "iterates through all Dependabot PRs of all Repos" do
      mock_pr_1 = instance_double("PullRequest", number: 1)
      mock_pr_2 = instance_double("PullRequest", number: 2)
      mock_pr_3 = instance_double("PullRequest", number: 3)
      mock_repo_1 = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr_1])
      mock_repo_2 = instance_double("Repo", name: "Repo 2", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr_2, mock_pr_3])
      allow(Repo).to receive(:all).and_return([
        mock_repo_1,
        mock_repo_2,
      ])

      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr_1, dry_run: false)
      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr_2, dry_run: false)
      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr_3, dry_run: false)

      AutoMerger.merge_dependabot_prs
    end

    it "should make a call to PolicyManager.remote_config_exists?, which should block merge if false" do
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      allow(policy_manager).to receive(:remote_config_exists?).and_return(false)

      expect(policy_manager).to receive(:remote_config_exists?)
      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("The remote .govuk_dependabot_merger.yml file is missing.\n").to_stdout
    end

    it "should make a call to PolicyManager.valid_remote_config_syntax?, which should block merge if false" do
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      allow(policy_manager).to receive(:valid_remote_config_syntax?).and_return(false)

      expect(policy_manager).to receive(:valid_remote_config_syntax?)
      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("The remote .govuk_dependabot_merger.yml YAML syntax is corrupt.\n").to_stdout
    end

    it "should make a call to PolicyManager.remote_config_api_version_supported?, which should block merge if false" do
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      allow(policy_manager).to receive(:remote_config_api_version_supported?).and_return(false)

      expect(policy_manager).to receive(:remote_config_api_version_supported?)
      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("The remote .govuk_dependabot_merger.yml file is using an unsupported API version.\n").to_stdout
    end
  end

  describe ".merge_dependabot_pr" do
    it "avoids approving or merging when in dry run mode" do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:is_auto_mergeable?).and_return(true)

      expect(mock_pr).to_not receive(:approve!)
      expect(mock_pr).to_not receive(:merge!)
      AutoMerger.merge_dependabot_pr(mock_pr, dry_run: true)
    end

    it "calls approve! and merge! when not in dry run mode" do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:is_auto_mergeable?).and_return(true)

      expect(mock_pr).to receive(:approve!)
      expect(mock_pr).to receive(:merge!)
      AutoMerger.merge_dependabot_pr(mock_pr, dry_run: false)
    end
  end

  describe ".analyse_dependabot_pr" do
    it "uses `merge_dependabot_pr` under the hood" do
      mock_pr = instance_double("PullRequest")
      mock_repo = instance_double("Repo", dependabot_pull_request: mock_pr)
      allow(Repo).to receive(:new).with("foo").and_return(mock_repo)

      expect(mock_repo).to receive(:dependabot_pull_request).with("1234")
      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr, dry_run: true)
      AutoMerger.analyse_dependabot_pr("https://github.com/alphagov/foo/pull/1234")
    end
  end
end
