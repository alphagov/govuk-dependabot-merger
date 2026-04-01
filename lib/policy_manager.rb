require_relative "./change_set"
require_relative "./version"

class PolicyManager
  def initialize(remote_config = {})
    @remote_config = remote_config
  end

  def defaults
    defaults = @remote_config["defaults"] || {}
    {
      auto_merge: defaults["auto_merge"].nil? ? true : defaults["auto_merge"],
      allowed_semver_bumps: defaults["allowed_semver_bumps"].nil? ? %i[patch minor] : defaults["allowed_semver_bumps"],
    }
  end

  def dependency_policy(dependency_name)
    dependency_overrides = @remote_config["overrides"]&.find { |dependency| dependency["dependency"] == dependency_name } || {}

    allowed_semver_bumps = dependency_overrides["allowed_semver_bumps"].nil? ? defaults[:allowed_semver_bumps] : dependency_overrides["allowed_semver_bumps"]
    auto_merge = dependency_overrides["auto_merge"].nil? ? defaults[:auto_merge] : dependency_overrides["auto_merge"]

    dependency = Dependency.new(dependency_name)
    auto_merge = false if auto_merge && !dependency.internal?

    {
      auto_merge:,
      allowed_semver_bumps: auto_merge ? allowed_semver_bumps.map(&:to_sym) : [],
    }
  end

  def deprecated_config_warnings
    warnings = []
    defaults = @remote_config["defaults"] || {}
    overrides = @remote_config["overrides"] || []

    if defaults.key?("update_external_dependencies")
      warnings << "the `update_external_dependencies` setting in `defaults` is deprecated and will be ignored. External dependencies are no longer auto-merged."
    end

    overrides.each do |override|
      if override.key?("update_external_dependencies")
        warnings << "the `update_external_dependencies` setting for `#{override['dependency']}` is deprecated and will be ignored. External dependencies are no longer auto-merged."
      end
    end

    warnings
  end

  def remote_config_exists?
    @remote_config["error"] != "404"
  end

  def valid_remote_config_syntax?
    @remote_config["error"] != "syntax"
  end

  def remote_config_api_version_supported?
    @remote_config["api_version"] == DependabotAutoMerge::VERSION
  end

  def is_auto_mergeable?(pull_request)
    reasons_not_to_merge(pull_request).count.zero?
  end

  def reasons_not_to_merge(pull_request)
    changes = ChangeSet.from_commit_message(pull_request.commit_message).changes

    reasons_not_to_merge = []
    changes.each do |change|
      unless change_allowed?(change.dependency.name, change.type)
        reasons_not_to_merge << "#{change.dependency.name} #{change.type} increase is not allowed by the derived policy for this dependency: #{dependency_policy(change.dependency.name)}"
      end
    end

    reasons_not_to_merge
  rescue UnexpectedCommitMessage => e
    [e.message]
  end

  def change_allowed?(dependency_name, change_type)
    policy = dependency_policy(dependency_name)
    policy[:auto_merge] && policy[:allowed_semver_bumps].include?(change_type)
  end
end
