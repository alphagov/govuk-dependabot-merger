require_relative "./github_client"

class PullRequest
  attr_reader :reasons_not_to_merge

  def initialize(api_response)
    @api_response = api_response
    @reasons_not_to_merge = []
  end

  def number
    @api_response.number
  end

  def is_auto_mergeable?
    unless validate_single_commit
      reasons_not_to_merge << "PR contains more than one commit."
    end

    reasons_not_to_merge.count.zero?
  end

  def validate_single_commit
    commits = GitHubClient.instance.pull_request_commits("alphagov/#{@api_response.base.repo.name}", @api_response.number)
    commits.count == 1
  end

  def merge!
    puts "Merging #{@api_response.base.repo.name}##{@api_response.number}..."
    GitHubClient.instance.merge_pull_request("alphagov/#{@api_response.base.repo.name}", @api_response.number)
  end
end
