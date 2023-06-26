require "octokit"

class GitHubAuthException < StandardError; end

class GitHubClient
  def self.instance
    unless ENV["AUTO_MERGE_TOKEN"]
      raise GitHubAuthException, "AUTO_MERGE_TOKEN missing"
    end

    Octokit::Client.new(access_token: ENV["AUTO_MERGE_TOKEN"])
  end
end
