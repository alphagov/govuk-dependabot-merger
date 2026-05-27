require_relative "./change_set"
require_relative "./version"

class PolicyManager
  def initialize(remote_config = {}, dependabot_cooldown_days = 0)
    @remote_config = remote_config
    @dependabot_cooldown_days = dependabot_cooldown_days
  end

  def defaults
    defaults = @remote_config["defaults"] || {}
    {
      update_external_dependencies: defaults["update_external_dependencies"].nil? ? false : defaults["update_external_dependencies"],
      auto_merge: defaults["auto_merge"].nil? || defaults["auto_merge"],
      allowed_semver_bumps: defaults["allowed_semver_bumps"].nil? ? %i[patch minor] : defaults["allowed_semver_bumps"],
    }
  end

  def dependency_policy(dependency_name)
    dependency_overrides = @remote_config["overrides"]&.find { |dependency| dependency["dependency"] == dependency_name } || {}

    update_external_dependencies = dependency_overrides["update_external_dependencies"].nil? ? defaults[:update_external_dependencies] : dependency_overrides["update_external_dependencies"]
    allowed_semver_bumps = dependency_overrides["allowed_semver_bumps"].nil? ? defaults[:allowed_semver_bumps] : dependency_overrides["allowed_semver_bumps"]
    auto_merge_setting = dependency_overrides.fetch("auto_merge", defaults[:auto_merge])

    dependency = Dependency.new(dependency_name)

    auto_merge = if dependency.internal?
                   auto_merge_internal?(auto_merge_setting)
                 else
                   auto_merge_external?(dependency_name, auto_merge_setting, update_external_dependencies)
                 end
    {
      auto_merge:,
      allowed_semver_bumps: auto_merge ? allowed_semver_bumps.map(&:to_sym) : [],
    }
  end

  def auto_merge_internal?(setting)
    # the setting is respected at all times for internal dependencies
    setting
  end

  def auto_merge_external?(dependency_name, auto_merge_setting, update_external_dependencies)
    if update_external_dependencies
      if auto_merge_setting && !dependabot_cooldown_days_acceptable?
        puts "blocking auto merging of #{dependency_name} because the configured dependabot cooldown is too low (#{@dependabot_cooldown_days})"
        false
      else
        auto_merge_setting
      end
    else
      false
    end
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

  def dependabot_cooldown_days_acceptable?
    @dependabot_cooldown_days >= 3
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
