require "httparty"
require "octokit"

class GitHubAuthException < StandardError; end

class GitHubClient
  def self.instance
    ensure_token_exists!

    Octokit::Client.new(access_token: ENV["AUTO_MERGE_TOKEN"])
  end

  def self.get(url)
    HTTParty.get(url, headers: { "Authorization": "Bearer #{GitHubClient.token}" })
  end

  def self.token
    ensure_token_exists!
    ENV["AUTO_MERGE_TOKEN"]
  end

  def self.ensure_token_exists!
    unless ENV["AUTO_MERGE_TOKEN"]
      raise GitHubAuthException, "AUTO_MERGE_TOKEN missing"
    end
  end
end
