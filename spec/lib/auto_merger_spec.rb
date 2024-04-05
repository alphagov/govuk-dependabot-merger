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
