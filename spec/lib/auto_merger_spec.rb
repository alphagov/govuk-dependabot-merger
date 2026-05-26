require "date"
require_relative "../../lib/auto_merger"

RSpec.describe AutoMerger do
  before :each do
    allow($stdout).to receive(:puts) # suppress console output as it gets noisy
  end

  let(:policy_manager) do
    mock_policy_manager = instance_double("PolicyManager")
    allow(mock_policy_manager).to receive(:remote_config_exists?).and_return(true)
    allow(mock_policy_manager).to receive(:valid_remote_config_syntax?).and_return(true)
    allow(mock_policy_manager).to receive(:remote_config_api_version_supported?).and_return(true)
    allow(mock_policy_manager).to receive(:is_auto_mergeable?).and_return(true)
    allow(PolicyManager).to receive(:new).and_return(mock_policy_manager)
    mock_policy_manager
  end

  describe ".invoke_merge_script!" do
    it "should fail silently if this is a bank holiday" do
      allow(Date).to receive(:bank_holidays).and_return([Date.today])

      expect(AutoMerger).not_to receive(:merge_dependabot_prs)
      expect { AutoMerger.invoke_merge_script! }.to output("Today is a bank holiday. Skipping auto-merge.\n").to_stdout
    end

    it "should call `merge_dependabot_prs` with `dry_run: false` if not a bank holiday" do
      allow(Date).to receive(:bank_holidays).and_return([])

      expect(AutoMerger).to receive(:merge_dependabot_prs).with(dry_run: false)
      AutoMerger.invoke_merge_script!
    end
  end

  describe ".pretend_invoke_merge_script!" do
    it "should call `merge_dependabot_prs` with `dry_run: true`" do
      allow(Date).to receive(:bank_holidays).and_return([])

      expect(AutoMerger).to receive(:merge_dependabot_prs).with(dry_run: true)
      AutoMerger.pretend_invoke_merge_script!
    end
  end

  describe ".merge_dependabot_prs" do
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

      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr_1, policy_manager, dry_run: false)
      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr_2, policy_manager, dry_run: false)
      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr_3, policy_manager, dry_run: false)

      AutoMerger.merge_dependabot_prs
    end

    it "forwards the `dry_run` keyword arg if passed" do
      mock_pr = instance_double("PullRequest", number: 1)
      mock_repo = instance_double("Repo", name: "Repo", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr, policy_manager, dry_run: true)

      AutoMerger.merge_dependabot_prs(dry_run: true)
    end

    it "should make a call to PolicyManager.remote_config_exists?, which should block merge if false" do
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      allow(policy_manager).to receive(:remote_config_exists?).and_return(false)

      expect(policy_manager).to receive(:remote_config_exists?)
      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("Repo 1: the remote .govuk_dependabot_merger.yml file is missing.\n").to_stdout
    end

    it "should make a call to PolicyManager.valid_remote_config_syntax?, which should block merge if false" do
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      allow(policy_manager).to receive(:valid_remote_config_syntax?).and_return(false)

      expect(policy_manager).to receive(:valid_remote_config_syntax?)
      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("Repo 1: the remote .govuk_dependabot_merger.yml YAML syntax is corrupt.\n").to_stdout
    end

    it "should make a call to PolicyManager.remote_config_api_version_supported?, which should block merge if false" do
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [mock_pr])
      allow(Repo).to receive(:all).and_return([mock_repo])

      allow(policy_manager).to receive(:remote_config_api_version_supported?).and_return(false)

      expect(policy_manager).to receive(:remote_config_api_version_supported?)
      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("Repo 1: the remote .govuk_dependabot_merger.yml file is using an unsupported API version.\n").to_stdout
    end

    it "should announce when no Dependabot PRs were found" do
      policy_manager # set up the mock policy manager object
      mock_repo = instance_double("Repo", name: "Repo 1", govuk_dependabot_merger_config: {}, dependabot_pull_requests: [])
      allow(Repo).to receive(:all).and_return([mock_repo])

      expect(AutoMerger).to_not receive(:merge_dependabot_pr)
      expect { AutoMerger.merge_dependabot_prs }.to output("Repo 1: no Dependabot PRs found.\n").to_stdout
    end
  end

  describe ".merge_dependabot_pr" do
    let(:mock_pr) do
      mock_pr = instance_double("PullRequest")
      allow(mock_pr).to receive(:is_auto_mergeable?).and_return(true)
      mock_pr
    end

    def expect_no_merge(mock_pr)
      expect(mock_pr).to_not receive(:approve!)
      expect(mock_pr).to_not receive(:merge!)
    end

    it "should make a call to PolicyManager.is_auto_mergeable?, which should block merge if false" do
      allow(policy_manager).to receive(:is_auto_mergeable?).and_return(false)
      allow(policy_manager).to receive(:reasons_not_to_merge).and_return(["Foo."])

      expect_no_merge(mock_pr)
      expect { AutoMerger.merge_dependabot_pr(mock_pr, policy_manager, dry_run: false) }.to output(
        "    ...auto-merging is against policy: Foo. Skipping.\n",
      ).to_stdout
    end

    it "should make a call to PullRequest's `is_auto_mergeable?`, which should block merge if false" do
      allow(mock_pr).to receive(:is_auto_mergeable?).and_return(false)
      allow(mock_pr).to receive(:reasons_not_to_merge).and_return(["Bar."])

      expect_no_merge(mock_pr)
      expect { AutoMerger.merge_dependabot_pr(mock_pr, policy_manager, dry_run: false) }.to output(
        "    ...bad PR: Bar. Skipping.\n",
      ).to_stdout
    end

    it "avoids approving or merging when in dry run mode" do
      expect_no_merge(mock_pr)
      AutoMerger.merge_dependabot_pr(mock_pr, policy_manager, dry_run: true)
    end

    it "calls approve! and merge! when not in dry run mode" do
      expect(mock_pr).to receive(:approve!)
      expect(mock_pr).to receive(:merge!)
      AutoMerger.merge_dependabot_pr(mock_pr, policy_manager, dry_run: false)
    end
  end

  describe ".analyse_dependabot_pr" do
    it "uses `merge_dependabot_pr` under the hood" do
      mock_pr = instance_double("PullRequest")
      mock_repo = instance_double("Repo", dependabot_pull_request: mock_pr, govuk_dependabot_merger_config: {})
      mock_policy_manager = {}
      allow(Repo).to receive(:new).with("foo").and_return(mock_repo)
      allow(PolicyManager).to receive(:new).and_return(mock_policy_manager)

      expect(mock_repo).to receive(:dependabot_pull_request).with("1234")
      expect(AutoMerger).to receive(:merge_dependabot_pr).with(mock_pr, mock_policy_manager, dry_run: true)
      AutoMerger.analyse_dependabot_pr("https://github.com/alphagov/foo/pull/1234")
    end
  end
end
