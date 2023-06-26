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
    if !validate_single_commit
      reasons_not_to_merge << "PR contains more than one commit."
    elsif !validate_files_changed
      reasons_not_to_merge << "PR changes files that should not be changed."
    end

    reasons_not_to_merge.count.zero?
  end

  def validate_single_commit
    commits = GitHubClient.instance.pull_request_commits("alphagov/#{@api_response.base.repo.name}", @api_response.number)
    commits.count == 1
  end

  def validate_files_changed
    commit = GitHubClient.instance.commit("alphagov/#{@api_response.base.repo.name}", @api_response.head.sha)
    files_changed = commit.files.map(&:filename)
    # TODO: support other package managers too (e.g. NPM)
    files_changed == ["Gemfile.lock"]
  end

  def merge!
    puts "Merging #{@api_response.base.repo.name}##{@api_response.number}..."
    GitHubClient.instance.merge_pull_request("alphagov/#{@api_response.base.repo.name}", @api_response.number)
  end
end
