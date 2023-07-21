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
    elsif !validate_ci_passes
      reasons_not_to_merge << "CI is failing or doesn't exist (should be a GitHub Action with a key called 'test')."
    elsif !validate_external_config_file
      reasons_not_to_merge << "The remote .govuk_automerge_config.yml file is missing or in the wrong format."
    else
      tell_dependency_manager_what_dependencies_are_allowed
      tell_dependency_manager_what_dependabot_is_changing

      if !dependency_manager.all_proposed_dependencies_on_allowlist?
        reasons_not_to_merge << "PR bumps a dependency that is not on the allowlist."
      elsif !dependency_manager.all_proposed_updates_semver_allowed?
        reasons_not_to_merge << "PR bumps a dependency to a higher semver than is allowed."
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

  def validate_ci_passes
    # No method exists for this in Octokit,
    # so we need to make the API call manually.
    uri = "https://api.github.com/repos/alphagov/#{@api_response.base.repo.name}/commits/#{@api_response.head.sha}/check-runs"
    check_runs = HTTParty.get(uri)["check_runs"]
    return false unless check_runs && (ci_run = check_runs.find { |run| run["name"] == "test" })

    ci_run["conclusion"] == "success"
  end

  def validate_external_config_file
    return false unless remote_config.dig("dependabot_auto_merge_config", "api_version") == DependabotAutoMerge::VERSION

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
  end

private

  def head_commit
    @head_commit ||= GitHubClient.instance.commit("alphagov/#{@api_response.base.repo.name}", @api_response.head.sha)
  end

  def gemfile_lock_changes
    head_commit.files.find { |file| file.filename == "Gemfile.lock" }.patch
  end

  def remote_config
    @remote_config ||= YAML.load(GitHubClient.instance.contents(
                                   "alphagov/#{@api_response.base.repo.name}",
                                   {
                                     accept: "application/vnd.github.raw",
                                     path: ".govuk_automerge_config.yml",
                                   },
                                 ))
  rescue Octokit::NotFound
    {}
  end

  def tell_dependency_manager_what_dependencies_are_allowed
    remote_config["dependabot_auto_merge_config"]["auto_merge"].each do |dependency|
      dependency_manager.allow_dependency_update(
        name: dependency["dependency"],
        allowed_semver_bumps: dependency["allowed_semver_bumps"],
      )
    end
  end

  def tell_dependency_manager_what_dependabot_is_changing
    lines_removed = gemfile_lock_changes.scan(/^-\s+([a-z\-_]+) \(([0-9.]+)\)$/)
    lines_added = gemfile_lock_changes.scan(/^\+\s+([a-z\-_]+) \(([0-9.]+)\)$/)
    previous_dependency_versions = lines_removed.map { |name, version| { name:, version: } }
    new_dependency_versions = lines_added.map { |name, version| { name:, version: } }
    new_dependency_versions.each do |new_dependency|
      previous_dependency = previous_dependency_versions.find { |dep| dep[:name] == new_dependency[:name] }
      dependency_manager.propose_dependency_update(
        name: new_dependency[:name],
        previous_version: previous_dependency[:version],
        next_version: new_dependency[:version],
      )
    end
  end
end
