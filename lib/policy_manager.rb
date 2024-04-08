require_relative "./change_set"
require_relative "./version"

class PolicyManager
  attr_reader :allowed_dependency_updates
  attr_accessor :change_set

  def initialize(remote_config = {})
    @remote_config = remote_config
    @allowed_dependency_updates = []
    @change_set = ChangeSet.new
    determine_allowed_dependencies
  end

  def defaults
    defaults = @remote_config["defaults"] || {}
    {
      update_external_dependencies: defaults["update_external_dependencies"].nil? ? false : defaults["update_external_dependencies"],
      auto_merge: defaults["auto_merge"].nil? ? true : defaults["auto_merge"],
      allowed_semver_bumps: defaults["allowed_semver_bumps"].nil? ? %i[patch minor] : defaults["allowed_semver_bumps"],
    }
  end

  def dependency_policy(dependency_name)
    dependency_overrides = @remote_config["overrides"]&.find { |dependency| dependency["dependency"] == dependency_name } || {}

    update_external_dependencies = dependency_overrides["update_external_dependencies"].nil? ? defaults[:update_external_dependencies] : dependency_overrides["update_external_dependencies"]
    allowed_semver_bumps = dependency_overrides["allowed_semver_bumps"].nil? ? defaults[:allowed_semver_bumps] : dependency_overrides["allowed_semver_bumps"]
    auto_merge = dependency_overrides["auto_merge"].nil? ? defaults[:auto_merge] : dependency_overrides["auto_merge"]

    dependency = Dependency.new(dependency_name)
    auto_merge = update_external_dependencies if auto_merge && !dependency.internal?

    {
      auto_merge:,
      allowed_semver_bumps: auto_merge ? allowed_semver_bumps : [],
    }
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
    @change_set = ChangeSet.from_commit_message(pull_request.commit_message)

    reasons_not_to_merge = []
    unless all_proposed_dependencies_on_allowlist?
      reasons_not_to_merge << "PR bumps a dependency that is not on the allowlist."
    end
    unless all_proposed_updates_semver_allowed?
      reasons_not_to_merge << "PR bumps a dependency to a higher semver than is allowed."
    end
    unless all_proposed_dependencies_are_internal?
      reasons_not_to_merge << "PR bumps an external dependency."
    end

    reasons_not_to_merge
  end

  def allow_dependency_update(name:, allowed_semver_bumps:)
    allowed_dependency_updates << { name:, allowed_semver_bumps: }
  end

  def all_proposed_dependencies_on_allowlist?
    change_set.changes.all? do |change|
      allowed_dependency_updates.map { |dep| dep[:name] }.include? change.dependency.name
    end
  end

  def all_proposed_updates_semver_allowed?
    change_set.changes.all? do |change|
      dependency = allowed_dependency_updates.find { |dep| dep[:name] == change.dependency.name }
      dependency.nil? || dependency[:allowed_semver_bumps].include?(change.type.to_s)
    end
  end

  def all_proposed_dependencies_are_internal?
    change_set.changes.all? { |change| change.dependency.internal? }
  end

private

  def determine_allowed_dependencies
    if @remote_config["auto_merge"]
      @remote_config["auto_merge"].each do |dependency|
        allow_dependency_update(
          name: dependency["dependency"],
          allowed_semver_bumps: dependency["allowed_semver_bumps"],
        )
      end
    end
  end
end
