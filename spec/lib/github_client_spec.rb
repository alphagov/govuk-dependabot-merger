require "octokit"
require_relative "../../lib/github_client"

RSpec.describe GitHubClient do
  describe "#instance" do
    it "should raise an exception if no `AUTO_MERGE_TOKEN` ENV var provided" do
      ENV["AUTO_MERGE_TOKEN"] = nil
      expect { GitHubClient.instance }.to raise_exception(GitHubAuthException, "AUTO_MERGE_TOKEN missing")
    end

    it "should return an Octokit instance" do
      set_up_mock_token
      expect(GitHubClient.instance).to be_a_kind_of(Octokit::Client)
    end
  end
end
