require "yaml"
require_relative "./github_client"

class PullRequest
  class CannotApproveException < StandardError; end
  class UnexpectedGitHubApiResponse < StandardError; end

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
    elsif !validate_dependabot_commit
      reasons_not_to_merge << "PR contains commit not signed by Dependabot."
    elsif !validate_files_changed
      reasons_not_to_merge << "PR changes files that should not be changed."
    elsif !validate_ci_workflow_exists
      reasons_not_to_merge << "CI workflow doesn't exist."
    elsif !validate_ci_passes
      reasons_not_to_merge << "CI workflow is failing."
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
    allowed_files = ["Gemfile.lock", "Gemfile", "#{@api_response.base.repo.name}.gemspec"]
    (files_changed - allowed_files).empty?
  end

  def validate_ci_workflow_exists
    !ci_workflow_run_id.nil?
  end

  def validate_ci_passes
    # No method exists for this in Octokit,
    # so we need to make the API call manually.
    jobs_url = "https://api.github.com/repos/alphagov/#{@api_response.base.repo.name}/actions/runs/#{ci_workflow_run_id}/jobs"
    jobs = GitHubClient.get(jobs_url)["jobs"]

    unfinished_jobs = jobs.reject { |job| job["status"] == "completed" }
    failed_jobs = jobs.reject { |job| %w[success skipped].include?(job["conclusion"]) }

    unfinished_jobs.empty? && failed_jobs.empty?
  end

  def approve!
    approval_message = <<~REVIEW_COMMENT
      This PR has been scanned and automatically approved by [govuk-dependabot-merger](https://github.com/alphagov/govuk-dependabot-merger).
    REVIEW_COMMENT
    response = GitHubClient.post(
      "https://api.github.com/repos/alphagov/#{@api_response.base.repo.name}/pulls/#{@api_response.number}/reviews",
      {
        event: "APPROVE",
        body: approval_message,
      },
    )
    if response.code != 200
      raise PullRequest::CannotApproveException, "#{response.message}: #{response.body}"
    end
  end

  def merge!
    GitHubClient.instance.merge_pull_request("alphagov/#{@api_response.base.repo.name}", @api_response.number)
  rescue Octokit::Error => e
    puts "Error merging pull request: #{e.message}"
  end

  def head_commit
    @head_commit ||= GitHubClient.instance.commit("alphagov/#{@api_response.base.repo.name}", @api_response.head.sha).commit
  end

  def commit_message
    head_commit.message
  end

  def validate_dependabot_commit
    head_commit.verification.verified && head_commit.author.name == "dependabot[bot]"
  end

private

  def ci_workflow_run_id
    @ci_workflow_run_id ||= begin
      # No method exists for this in Octokit,
      # so we need to make the API call manually.
      uri = "https://api.github.com/repos/alphagov/#{@api_response.base.repo.name}/actions/runs?head_sha=#{@api_response.head.sha}"
      ci_workflow_api_response = GitHubClient.get(uri)

      if ci_workflow_api_response["workflow_runs"].nil?
        raise(
          PullRequest::UnexpectedGitHubApiResponse,
          "Error fetching CI workflow in API response for #{uri}\n#{ci_workflow_api_response}",
        )
      end

      ci_workflow_api_response["workflow_runs"]
        .find { |run| run["name"] == "CI" }
        &.dig("id")
    end
  end
end
