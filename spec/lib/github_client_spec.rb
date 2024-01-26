require "octokit"
require_relative "../../lib/github_client"

RSpec.describe GitHubClient do
  describe ".instance" do
    it "should raise an exception if no `AUTO_MERGE_TOKEN` ENV var provided" do
      ENV["AUTO_MERGE_TOKEN"] = nil
      expect { GitHubClient.instance }.to raise_exception(GitHubAuthException, "AUTO_MERGE_TOKEN missing")
    end

    it "should return an Octokit instance" do
      set_up_mock_token
      expect(GitHubClient.instance).to be_a_kind_of(Octokit::Client)
    end
  end

  describe ".get" do
    it "should raise an exception if no `AUTO_MERGE_TOKEN` ENV var provided" do
      ENV["AUTO_MERGE_TOKEN"] = nil
      expect { GitHubClient.get("http://example.com") }.to raise_exception(GitHubAuthException, "AUTO_MERGE_TOKEN missing")
    end

    it "should make an authenticated GET request via HTTParty" do
      url = "http://example.com"
      token = "foo"

      expect(HTTParty).to receive(:get).with(url, headers: { "Authorization": "Bearer #{token}" })

      ENV["AUTO_MERGE_TOKEN"] = token
      GitHubClient.get(url)
    end
  end

  describe ".post" do
    it "should raise an exception if no `AUTO_MERGE_TOKEN` ENV var provided" do
      ENV["AUTO_MERGE_TOKEN"] = nil
      expect { GitHubClient.post("http://example.com", {}) }.to raise_exception(GitHubAuthException, "AUTO_MERGE_TOKEN missing")
    end

    it "should make an authenticated POST request via HTTParty" do
      url = "http://example.com"
      hash = { foo: "bar" }
      json = '{"foo":"bar"}'
      token = "foo"

      expect(HTTParty).to receive(:post).with(url, body: json, headers: { "Authorization": "Bearer #{token}" })

      ENV["AUTO_MERGE_TOKEN"] = token
      GitHubClient.post(url, hash)
    end
  end
end
