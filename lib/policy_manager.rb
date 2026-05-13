require_relative "./change_set"
require_relative "./version"

class PolicyManager
  def initialize(remote_config = {}, cooldown_days: 0)
    @remote_config = remote_config
    @cooldown_days = cooldown_days
  end

  def defaults
    defaults = @remote_config["defaults"] || {}
    {
      auto_merge: defaults["auto_merge"].nil? || defaults["auto_merge"],
      allowed_semver_bumps: defaults["allowed_semver_bumps"].nil? ? %i[patch minor] : defaults["allowed_semver_bumps"],
      update_external_dependencies: defaults["update_external_dependencies"].nil? ? false : defaults["update_external_dependencies"],
    }
  end

  def dependency_policy(dependency_name)
    dependency_overrides = @remote_config["overrides"]&.find { |dependency| dependency["dependency"] == dependency_name } || {}

    allowed_semver_bumps = dependency_overrides["allowed_semver_bumps"].nil? ? defaults[:allowed_semver_bumps] : dependency_overrides["allowed_semver_bumps"]
    auto_merge = dependency_overrides["auto_merge"].nil? ? defaults[:auto_merge] : dependency_overrides["auto_merge"]
    update_external_dependencies = dependency_overrides["update_external_dependencies"].nil? ? defaults[:update_external_dependencies] : dependency_overrides["update_external_dependencies"]

    dependency = Dependency.new(dependency_name)
    if auto_merge && !dependency.internal?
      auto_merge = update_external_dependencies && @cooldown_days >= 3
    end

    {
      auto_merge:,
      allowed_semver_bumps: auto_merge ? allowed_semver_bumps.map(&:to_sym) : [],
    }
  end

  def cooldown_warnings
    warnings = []
    defaults_config = @remote_config["defaults"] || {}
    overrides = @remote_config["overrides"] || []

    if defaults_config["update_external_dependencies"] && @cooldown_days < 3
      warnings << "external dependencies are configured for auto-merging (`update_external_dependencies: true` in defaults), but the Dependabot cooldown is insufficient (#{@cooldown_days} days). A minimum of 3 days is required."
    end

    overrides.each do |override|
      if override["update_external_dependencies"] && @cooldown_days < 3
        warnings << "external dependencies for `#{override['dependency']}` are configured for auto-merging, but the Dependabot cooldown is insufficient (#{@cooldown_days} days). A minimum of 3 days is required."
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
