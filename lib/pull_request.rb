require "httparty"
require "yaml"
require_relative "./dependency_manager"
require_relative "./github_client"
require_relative "./version"

class PullRequest
  class CannotApproveException < StandardError; end

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
      reasons_not_to_merge << "Repo lacks a GitHub Action workflow named 'CI'."
    elsif !validate_ci_passes
      reasons_not_to_merge << "At least one of the 'CI' GitHub Action workflow jobs is failing."
    elsif !validate_external_config_file
      reasons_not_to_merge << "The remote .govuk_dependabot_merger.yml file is missing or in the wrong format."
    else
      tell_dependency_manager_what_dependencies_are_allowed
      tell_dependency_manager_what_dependabot_is_changing

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
    path_to_ci_workflow.nil? ? false : true
  end

  def validate_ci_passes
    # No method exists for this in Octokit,
    # so we need to make the API call manually.
    uri = "https://api.github.com/repos/alphagov/#{@api_response.base.repo.name}/commits/#{@api_response.head.sha}/check-runs"
    check_runs = HTTParty.get(uri)["check_runs"]

    ci_workflow_config = YAML.safe_load(GitHubClient.instance.contents(
                                        "alphagov/#{@api_response.base.repo.name}",
                                        {
                                          accept: "application/vnd.github.raw",
                                          path: path_to_ci_workflow,
                                        },
                                      ))

    ci_workflow_config["jobs"].each do |job_id, job_config|
      corresponding_job = check_runs.find { |run| run["name"] == job_config["name"] }

      if corresponding_job.nil? || corresponding_job["conclusion"] != "success"
        return false
      end
    end

    true
  end

  def validate_external_config_file
    return false unless remote_config["api_version"] == DependabotAutoMerge::VERSION

    true
  end

  def approve!
    approval_message = <<~REVIEW_COMMENT
      This PR has been scanned and automatically approved by [govuk-dependabot-merger](https://github.com/alphagov/govuk-dependabot-merger).
    REVIEW_COMMENT
    response = HTTParty.post(
      "https://api.github.com/repos/alphagov/#{@api_response.base.repo.name}/pulls/#{@api_response.number}/reviews",
      body: {
        event: "APPROVE",
        body: approval_message,
      }.to_json,
      headers: {
        "Authorization": "Bearer #{GitHubClient.token}",
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

  def gemfile_lock_changes
    head_commit.files.find { |file| file.filename == "Gemfile.lock" }.patch
  end

  def remote_config
    @remote_config ||= YAML.safe_load(GitHubClient.instance.contents(
                                        "alphagov/#{@api_response.base.repo.name}",
                                        {
                                          accept: "application/vnd.github.raw",
                                          path: ".govuk_dependabot_merger.yml",
                                        },
                                      ))
  rescue Octokit::NotFound
    {}
  end

  def tell_dependency_manager_what_dependencies_are_allowed
    remote_config["auto_merge"].each do |dependency|
      dependency_manager.allow_dependency_update(
        name: dependency["dependency"],
        allowed_semver_bumps: dependency["allowed_semver_bumps"],
      )
    end
  end

  def tell_dependency_manager_what_dependabot_is_changing
    dependency_updates = commit_message.scan(/(?:Bump|Updates) `?(\w+)`? from (\d+\.\d+\.\d+) to (\d+\.\d+\.\d+)/)

    mentioned_dependencies = dependency_updates.to_h { |name, from_version, to_version| [name, { from_version:, to_version: }] }

    lines_removed = gemfile_lock_changes.scan(/^-\s+([a-z\-_]+) \(([0-9.]+)\)$/)
    lines_added = gemfile_lock_changes.scan(/^\+\s+([a-z\-_]+) \(([0-9.]+)\)$/)

    lines_removed.each do |name, version|
      dependency_manager.remove_dependency(name:, version:) if mentioned_dependencies[name]&.fetch(:from_version) == version
    end

    lines_added.each do |name, version|
      dependency_manager.add_dependency(name:, version:) if mentioned_dependencies[name]&.fetch(:to_version) == version
    end
  end

  private

  def path_to_ci_workflow
    workflows = GitHubClient.instance.workflows("alphagov/#{@api_response.base.repo.name}")
    ci_workflow = workflows[:workflows].find { |workflow| workflow["name"] == "CI" }
    ci_workflow.nil? ? nil : ci_workflow[:path]
  end
end
