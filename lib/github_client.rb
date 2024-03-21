require "httparty"
require "octokit"

class GitHubAuthException < StandardError; end

module GitHubClient
  def self.instance
    Octokit::Client.new(access_token: token)
  end

  def self.get(url)
    HTTParty.get(url, headers: { "Authorization": "Bearer #{token}" })
  end

  def self.post(url, hash)
    HTTParty.post(url, body: hash.to_json, headers: { "Authorization": "Bearer #{token}" })
  end

  private_class_method def self.token
    ENV["AUTO_MERGE_TOKEN"] || raise(GitHubAuthException, "AUTO_MERGE_TOKEN missing")
  end
end
