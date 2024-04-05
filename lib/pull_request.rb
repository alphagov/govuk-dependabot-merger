require "yaml"
require_relative "./change_set"
require_relative "./dependency_manager"
require_relative "./github_client"

class PullRequest
  class CannotApproveException < StandardError; end
  class UnexpectedGitHubApiResponse < StandardError; end

  attr_reader :dependency_manager, :reasons_not_to_merge

  def initialize(api_response, dependency_manager = DependencyManager.new)
    @api_response = api_response
    @dependency_manager = dependency_manager
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
    elsif !validate_ci_workflow_exists
      reasons_not_to_merge << "CI workflow doesn't exist."
    elsif !validate_ci_passes
      reasons_not_to_merge << "CI workflow is failing."
    elsif !dependency_manager.remote_config_exists?
      reasons_not_to_merge << "The remote .govuk_dependabot_merger.yml file is missing."
    elsif !dependency_manager.valid_remote_config_syntax?
      reasons_not_to_merge << "The remote .govuk_dependabot_merger.yml YAML syntax is corrupt."
    elsif !dependency_manager.remote_config_api_version_supported?
      reasons_not_to_merge << "The remote .govuk_dependabot_merger.yml file is using an unsupported API version."
    else
      dependency_manager.change_set = ChangeSet.from_commit_message(commit_message)

      if !dependency_manager.all_proposed_dependencies_on_allowlist?
        reasons_not_to_merge << "PR bumps a dependency that is not on the allowlist."
      elsif !dependency_manager.all_proposed_updates_semver_allowed?
        reasons_not_to_merge << "PR bumps a dependency to a higher semver than is allowed."
      elsif !dependency_manager.all_proposed_dependencies_are_internal?
        reasons_not_to_merge << "PR bumps an external dependency."
      end
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
    @head_commit ||= GitHubClient.instance.commit("alphagov/#{@api_response.base.repo.name}", @api_response.head.sha)
  end

  def commit_message
    head_commit.commit.message
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
